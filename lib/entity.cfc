component accessors="true" extends="helper" {

  // property name="schema";
  property name="csvDelimiter";
  property name="charset";
  property name="writeFlushLimit";

  function init(){
    this.csvDelimiter = chr(9); // tab
    this.setwriteFlushLimit(500);
    this.charset = createObject("java", "java.nio.charset.Charset").forName("UTF-8");
    this.s3 = new s3();
    this.tables = new tableSchema();
    this.merge = new merge();

    return this;
  }

  public any function handleEntities(entityList){
    var result = {success: false};

    for (var entity in arguments.entityList){
      outputH1("<div id=""#entity#"">Syncing #entity#</div>");
      flush;

      outputH2("Working on #entity# Inserts/Updates");
      outputImportant("Import mode for #entity# is #this.tables.getEntityImportMode(entity)#");
      var manifestResult = this.s3.downloadEntityManifestFromOA(entity = entity);
      if (!manifestResult.success){
        break;
      }

      // process snapshots
      var processEntityResult = processEntitySnapshots(entity = entity);
      if (!processEntityResult.success){
        break;
      }

      // work on merged ids that need to be deleted
      outputH2("Working on #entity# Deletions");
      var processMergeResult = this.merge.processEntityMergedIds(entity = entity);
      result.success = true;

      if (!processMergeResult.success){
        break;
      }

      if (this.tables.getEntityImportMode(entity) == "append"){
        // append mode disables primary key indexes
        // it's faster to import, but we need to rebuild them
        // and hope that they are no duplicates
        outputH2("Working on #entity# primary key reindexing (append mode only)");
        var rebuildIndexResult = this.tables.rebuildPrimaryKeyIndex(entity = entity);
        if (!rebuildIndexResult.success){
          break;
        }
      }
    }

    return result;
  }

  /**
   * Loops through entity snapshots and loads them into the database
   *
   * @entity
   * @snapshotLimit set to numeric value if you want to limit the number of snapshot imports. Mostly for debugging purposes
   */
  private any function processEntitySnapshots(required entity, snapshotLimit = 1){
    var result = {success: false};

    var filesToProcess = getEntityFilesNotComplete(entity = arguments.entity);

    if (filesToProcess.success){
      var limit = 0;

      if (filesToProcess.data.len() > 0){
        outputH2("Processing remaining #arguments.entity# snapshots");
        if (arguments.keyExists("snapshotlimit")){
          outputImportant("Limiting snapshot processing to #arguments.snapshotLimit#");
        }
      }
      else{
        outputImportant("All up to date with #arguments.entity# snapshots");
        result.success = true;
      }

      for (var snapshot in filesToProcess.data){
        if (arguments.keyExists("snapshotLimit")){
          if (limit == arguments.snapshotLimit){
            break;
          }
        }

        writeOutput("<div id=""#arguments.entity#-#dateFormat(snapshot.updateDate, "yyyy-mm-dd")#"" class=""snapshot"" style=""background-color:#getRandomColor()#;"">");

        outputH2("#uCase(arguments.entity)# &##10142; #dateFormat(snapshot.updateDate, "yyyy-mm-dd")# &##10142; #uCase(snapshot.filename)# (File #snapshot.filenumber# of #snapshot.totalfiles#) contains #numberFormat(snapshot.meta.record_count)# records");
        flush;

        var compressedFilePath = application.localpath & "files\compressed\#snapshot.updateDate#\#snapshot.filename#";
        if (!directoryExists(getDirectoryFromPath(compressedFilePath))){
          directoryCreate(getDirectoryFromPath(compressedFilePath));
        }
        outputh3("Download Compressed Snapshot File");

        outputNormal("Starting to download file located at #snapshot.url#");
        flush;
        var compressedFile = this.s3.streamFileFromOA(snapshot.url, compressedFilePath);

        if (compressedFile.success){
          outputSuccess("Finished downloading compressed file to #compressedFilePath#");
          flush;
          var uncompressedPath = application.localpath & "files\uncompressed\#snapshot.updateDate#\";

          if (!directoryExists(uncompressedPath)){
            directoryCreate(uncompressedPath);
          }

          var unCompressedFile = gunzipFile(compressedFilePath, uncompressedPath);

          if (unCompressedFile.success){
            deleteFile(compressedFilePath, true);

            var processed = processEntityData(
              entity = arguments.entity,
              snapshotfile = unCompressedFile,
              snapshotMetaData = snapshot
            );
            if (processed.success){
              var imported = importDataToStaging(entity = arguments.entity);
              if (!imported){
                outputError("There was an error during the database import. Script has been halted. Please review the \files\loader\#arguments.entity#\logs folder for more details");
                break;
              }
              else{
                var merged = {success: true};
                if (this.tables.getEntityImportMode(arguments.entity) == "merge"){
                  var merged = mergeEntityStageWithMain(entity = arguments.entity);
                }

                if (merged.success){
                  deleteFile(unCompressedFile.filepath, true);

                  outputh3("Cleaning up #arguments.entity# staging tables/files");

                  var clear = {success: true};
                  if (this.tables.getEntityImportMode(arguments.entity) == "merge"){
                    // clear entity staging tables
                    var clear = this.tables.clearStagingTables(entity = arguments.entity);
                  }

                  // delete entity csv files
                  var csvDelete = deleteEntityCsvDirectory(entity = arguments.entity);

                  if (clear.success && csvDelete.success){
                    logEntityImport(
                      entity = arguments.entity,
                      updatedate = snapshot.updateDate,
                      filenumber = snapshot.filenumber,
                      filename = snapshot.filename,
                      fileurl = snapshot.url,
                      totalfiles = snapshot.totalfiles,
                      recordcount = snapshot.meta.record_count,
                      manifesthash = filesToProcess.hash
                    );
                    result.success = true;
                  }
                }
              }
            }
          }
        }
        limit++;
        System = createObject("java", "java.lang.System");
        System.gc();
        writeOutput("</div><script>updateBookmark(""#arguments.entity#-#dateFormat(snapshot.updateDate, "yyyy-mm-dd""")#)</script>");
      }
    }

    return result;
  }


  /**
   * Helper function to route processing of entity data
   *
   * @entity
   * @snapshotfile uncompressed data file to process
   */
  private any function processEntityData(entity, snapshotfile, snapshotMetaData){
    var result = {success: false};

    outputH3("Creating the csv files for import into Oracle");
    outputNormal("Using #this.getwriteFlushLimit()# as the number of records to save in memory before flushing to the file");
    flush;

    switch (arguments.entity){
      case "authors":
        result = processAuthorsData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "concepts":
        result = processConceptsData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "domains":
        result = processDomainsData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "fields":
        result = processFieldsData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "funders":
        result = processFundersData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "institutions":
        result = processInstitutionsData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "publishers":
        result = processPublishersData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "sources":
        result = processSourcesData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "subfields":
        result = processSubfieldsData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "topics":
        result = processTopicsData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      case "works":
        result = processWorksData(snapshotfile = arguments.snapshotfile, snapshotMetaData = arguments.snapshotMetaData);
        break;
      default:
    }

    return result;
  }

  /**
   * Reviews the manifestfile and returns snapshot data that needs to be loaded
   *
   * @entity
   */
  private struct function getEntityFilesNotComplete(entity){
    var result = getManifestFile(entity = arguments.entity);

    // defaults that will return everything
    var compareDate = createDate(1900, 1, 1);
    var compareFileNumber = 0;

    var latestSync = getLatestEntityFileSynced(entity = arguments.entity);

    if (latestSync.recordcount == 1){
      // check hashes to see if manifest file changed
      if (result.hash !== latestSync.manifesthash && this.tables.getEntityImportMode(arguments.entity) == "append"){
        outputImportant("Change detected in the #arguments.entity# manifest file. Assuming OpenAlex data was refreshed. Starting import from the beginning. (append mode only)");
      }
      else{
        compareDate = latestSync.updateDate;
        compareFileNumber = latestSync.filenumber;
        outputNormal("Latest synced #arguments.entity# snapshot found is #dateFormat(compareDate, "yyyy-mm-dd")# &##10142; #latestSync.filename#");
      }
    }
    result.latest = {snapshotdate: compareDate, snapshotfile: compareFileNumber}

    // append only: clear out records that need to be reset
    // We don't know if the script terminates mid run. Maybe there was an error with the sqlloader import, etc
    // We have to clear out possible incomplete snapshot data and start over
    // Also, if the manifest file changes, we start over completely
    if (this.tables.getEntityImportMode(arguments.entity) == "append"){
      var clear = this.tables.clearMainTablesPastSnapshot(entity = arguments.entity, latestSnapshot = result.latest);
    }

    // filter on snapshots that need processing
    result.data = result.data.filter((row) => {
      var dateComparison = dateCompare(row.updateDate, compareDate, "d");
      return dateComparison == 1 || (dateComparison == 0 ? row.filenumber > compareFileNumber : false);
    });

    return result;
  }

  private any function getManifestFile(entity){
    var result = {success: false, hash: "", data: []};

    var manifestPath = application.localpath & "files\manifest\#arguments.entity#.json";
    if (fileExists(manifestPath)){
      var fileData = fileRead(manifestPath);
      result.hash = hash(fileData, "MD5");
      fileData = fileData.deserializeJSON();
      result.success = true;
      result.entity = arguments.entity;

      // sort first so it will be added to the array properly
      fileData.entries = fileData.entries.sort(function(e1, e2){
        return compare(e1.url, e2.url);
      });

      if (isArray(fileData.entries)){
        for (entry in fileData.entries){
          var updatedateFind = reFindNoCase("updated_date=(\d{4}-\d{2}-\d{2})", entry.url, 0, true);
          var updateDate = "";
          var updateYear = "";
          var updateMonth = "";
          var updateDay = "";
          if (
            isStruct(updatedateFind) && updatedateFind.keyExists("match") && isArray(updatedateFind.match) && updatedateFind.match.len() == 2
          ){
            updateDate = updatedateFind.match[2];
            updateYear = listFirst(updateDate, "-");
            updateMonth = listGetAt(updateDate, 2, "-")
            updateDay = listLast(updateDate, "-");
          }

          var filename = listLast(entry.url, "/");
          var filenumberReg = filename.reFindNoCase("part_(\d{3})", 0, true);
          var fileNumber = "";
          if (
            isStruct(filenumberReg) && filenumberReg.keyExists("match") && isArray(filenumberReg.match) && filenumberReg.match.len() == 2
          ){
            fileNumber = numberFormat(filenumberReg.match[2]) + 1;
          }

          result.data.append({
            meta: entry.meta,
            s3url: entry.url,
            url: entry.url.reReplaceNoCase("s3://openalex/data/", application.openalexbaseurl),
            filename: filename,
            fileNumber: fileNumber,
            totalfiles: fileData.entries
              .filter((row) => {
                return findNoCase(updatedate, row.url);
              })
              .len(),
            updateDate: updateDate,
            updateYear: updateYear,
            updateMonth: updateMonth,
            updateDay: updateDay
          });
        }
      }
    }

    return result;
  }

  private any function getLatestEntityFileSynced(entity){
    return queryExecute(
      "select *
    from #getSchema()#.entitylatestsync
    where entity=:entity",
      {entity: {value: arguments.entity, cfsqltype: "varchar"}},
      {datasource: getDatasource(), result: "qryresult"}
    );
  }

  private struct function setupEntityCSVFiles(entity){
    var result = {};

    // loop through enbtity tables and setup csv files
    for (entitytable in this.tables.getActiveTables(arguments.entity)){
      var simplifiedName = entitytable.name.reReplaceNocase("_", "", "All");

      // set csv path
      result.csv[simplifiedName] = application.localpath & "files\loader\#arguments.entity#\csv\#simplifiedName#.csv";

      // create buffered writer
      result.writer[simplifiedName] = createObject("java", "java.io.BufferedWriter").init(
        createObject("java", "java.io.FileWriter").init(result.csv[simplifiedName], this.charset)
      );

      // set csv headers
      result.writer[simplifiedName].write(entitytable.fields.listChangeDelims(this.csvDelimiter));
      result.writer[simplifiedName].newLine();

      // set temp location for row data
      result.data[simplifiedName] = [];
    }

    return result;
  }


  private any function processSubfieldsData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("subfields");

        // Create a file object
        var subfieldsData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;
        // holds single row of data to process
        var line = {};

        // loop through rows of data
        while (!fileIsEOF(subfieldsData)){
          line = fileReadLine(subfieldsData).deserializeJSON();

          if (inputs.data.keyExists("subfields")){
            // subfields
            // if (!line.keyExists("keywords")){
            //   line.keywords = "";
            // }

            inputs.data.subfields.append(line.id);
            inputs.data.subfields.append(arguments.snapshotMetaData.updateDate);
            inputs.data.subfields.append(arguments.snapshotMetaData.filenumber);
            inputs.data.subfields.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            (line.display_name_alternatives.isEmpty()) ? inputs.data.subfields.append("") : inputs.data.subfields.append(
              line.display_name_alternatives.slice(1, min(line.display_name_alternatives.len(), 100)).toJson()
            );
            inputs.data.subfields.append(line.description);
            inputs.data.subfields.append(line.field.id);
            inputs.data.subfields.append(line.domain.id);
            inputs.data.subfields.append(line.works_count);
            inputs.data.subfields.append(line.cited_by_count);
            inputs.data.subfields.append(line.works_api_url);
            inputs.data.subfields.append(line.updated_date);

            inputs.writer.subfields.write(inputs.data.subfields.toList(this.csvDelimiter));
            inputs.writer.subfields.newLine();
            inputs.data.subfields.clear();
          }

          // subfields ids
          if (inputs.data.keyExists("subfieldsids")){
            if (line.keyExists("ids")){
              // if (!line.ids.keyExists("wikipedia")){
              //   line.ids.wikipedia = "";
              // }

              inputs.data.subfieldsids.append(line.id);
              inputs.data.subfieldsids.append(arguments.snapshotMetaData.updateDate);
              inputs.data.subfieldsids.append(arguments.snapshotMetaData.filenumber);
              inputs.data.subfieldsids.append(line.ids.wikidata);
              inputs.data.subfieldsids.append(line.ids.wikipedia);

              inputs.writer.subfieldsids.write(inputs.data.subfieldsids.toList(this.csvDelimiter));
              inputs.writer.subfieldsids.newLine();
              inputs.data.subfieldsids.clear();
            }
          }

          // subfields siblings
          if (inputs.data.keyExists("subfieldssiblings")){
            if (line.keyExists("siblings")){
              for (var sibling in line.siblings){
                inputs.data.subfieldssiblings.append(line.id);
                inputs.data.subfieldssiblings.append(sibling.id);
                inputs.data.subfieldssiblings.append(arguments.snapshotMetaData.updateDate);
                inputs.data.subfieldssiblings.append(arguments.snapshotMetaData.filenumber);

                inputs.writer.subfieldssiblings.write(inputs.data.subfieldssiblings.toList(this.csvDelimiter));
                inputs.writer.subfieldssiblings.newLine();
                inputs.data.subfieldssiblings.clear();
              }
            }
          }

          // subfields topics
          if (inputs.data.keyExists("subfieldstopics")){
            if (line.keyExists("topics")){
              for (var topic in line.topics){
                inputs.data.subfieldstopics.append(line.id);
                inputs.data.subfieldstopics.append(topic.id);
                inputs.data.subfieldstopics.append(arguments.snapshotMetaData.updateDate);
                inputs.data.subfieldstopics.append(arguments.snapshotMetaData.filenumber);

                inputs.writer.subfieldstopics.write(inputs.data.subfieldstopics.toList(this.csvDelimiter));
                inputs.writer.subfieldstopics.newLine();
                inputs.data.subfieldstopics.clear();
              }
            }
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "subfields error");
      }
      finally{
        fileClose(subfieldsData);
        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }

    return result;
  }

  private any function processTopicsData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("topics");

        // Create a file object
        var topicsData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;
        // holds single row of data to process
        var line = {};

        // loop through rows of data
        while (!fileIsEOF(topicsData)){
          line = fileReadLine(topicsData).deserializeJSON();

          if (inputs.data.keyExists("topics")){
            // topics
            if (!line.keyExists("keywords")){
              line.keywords = "";
            }

            inputs.data.topics.append(line.id);
            inputs.data.topics.append(arguments.snapshotMetaData.updateDate);
            inputs.data.topics.append(arguments.snapshotMetaData.filenumber);
            inputs.data.topics.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            inputs.data.topics.append(line.description);
            (line.keywords.isEmpty()) ? inputs.data.topics.append("") : inputs.data.topics.append(
              line.keywords.slice(1, min(line.keywords.len(), 100)).toJson()
            );
            inputs.data.topics.append(line.subfield.id);
            inputs.data.topics.append(line.field.id);
            inputs.data.topics.append(line.domain.id);
            inputs.data.topics.append(line.works_count);
            inputs.data.topics.append(line.cited_by_count);
            inputs.data.topics.append(line.updated_date);

            inputs.writer.topics.write(inputs.data.topics.toList(this.csvDelimiter));
            inputs.writer.topics.newLine();
            inputs.data.topics.clear();
          }

          // topics ids
          if (inputs.data.keyExists("topicsids")){
            if (line.keyExists("ids")){
              if (!line.ids.keyExists("wikipedia")){
                line.ids.wikipedia = "";
              }

              inputs.data.topicsids.append(line.id);
              inputs.data.topicsids.append(arguments.snapshotMetaData.updateDate);
              inputs.data.topicsids.append(arguments.snapshotMetaData.filenumber);
              inputs.data.topicsids.append(line.ids.openalex);
              inputs.data.topicsids.append(line.ids.wikipedia);

              inputs.writer.topicsids.write(inputs.data.topicsids.toList(this.csvDelimiter));
              inputs.writer.topicsids.newLine();
              inputs.data.topicsids.clear();
            }
          }

          // topics siblings
          if (inputs.data.keyExists("topicssiblings")){
            if (line.keyExists("siblings")){
              for (var sibling in line.siblings){
                inputs.data.topicssiblings.append(line.id);
                inputs.data.topicssiblings.append(sibling.id);
                inputs.data.topicssiblings.append(arguments.snapshotMetaData.updateDate);
                inputs.data.topicssiblings.append(arguments.snapshotMetaData.filenumber);

                inputs.writer.topicssiblings.write(inputs.data.topicssiblings.toList(this.csvDelimiter));
                inputs.writer.topicssiblings.newLine();
                inputs.data.topicssiblings.clear();
              }
            }
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "topics error");
      }
      finally{
        fileClose(topicsData);
        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }

    return result;
  }

  private any function processWorksData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("works");

        // Create a file object
        var worksData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;
        // holds single row of data to process
        var line = {};

        // loop through rows of data
        while (!fileIsEOF(worksData)){
          line = fileReadLine(worksData).deserializeJSON();

          if (inputs.data.keyExists("works")){
            if (!line.keyExists("doi")){
              line.doi = "";
            }
            if (!line.keyExists("title")){
              line.title = "";
            }
            if (!line.keyExists("display_name")){
              line.display_name = "";
            }
            // if (!line.keyExists("abstract_inverted_index")){
            //   line.abstract_inverted_index = [];
            // }
            if (!line.keyExists("language")){
              line.language = "";
            }

            // works
            inputs.data.works.append(line.id);
            inputs.data.works.append(arguments.snapshotMetaData.updateDate);
            inputs.data.works.append(arguments.snapshotMetaData.filenumber);
            inputs.data.works.append(line.doi);
            inputs.data.works.append(line.title.reReplaceNoCase("[\n\r\t]", " ", "all"));
            inputs.data.works.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            inputs.data.works.append(line.publication_year);
            inputs.data.works.append(line.publication_date);
            inputs.data.works.append(line.type);
            inputs.data.works.append(line.cited_by_count);
            (line.is_retracted) ? inputs.data.works.append("1") : inputs.data.works.append("0");
            (line.is_paratext) ? inputs.data.works.append("1") : inputs.data.works.append("0");
            inputs.data.works.append(line.cited_by_api_url);
            // (line.abstract_inverted_index.isEmpty()) ? inputs.data.works.append("") : inputs.data.works.append(line.abstract_inverted_index.toJson());
            inputs.data.works.append(line.language);

            inputs.writer.works.write(inputs.data.works.toList(this.csvDelimiter));
            inputs.writer.works.newLine();
            inputs.data.works.clear();
          }

          // authorships
          if (inputs.data.keyExists("worksauthorships")){
            for (var authorship in line.authorships){
              if (
                !authorship.keyExists("institutions") || authorship.keyExists("institutions") && authorship.institutions.isEmpty()
              ){
                authorship.institutions = [{id: ""}];
              }
              if (!authorship.keyExists("raw_affiliation_string")){
                authorship.raw_affiliation_string = "";
              }
              if (!authorship.keyExists("raw_author_name")){
                authorship.raw_author_name = "";
              }

              // need every record unique and the data coming from OA isn't always
              inputs.data.worksauthorships.append(hash(createUUID(), "MD5"));
              inputs.data.worksauthorships.append(line.id);
              inputs.data.worksauthorships.append(authorship.author.id);
              inputs.data.worksauthorships.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksauthorships.append(arguments.snapshotMetaData.filenumber);
              inputs.data.worksauthorships.append(authorship.author_position);
              inputs.data.worksauthorships.append(authorship.raw_author_name.reReplaceNoCase("[\n\r\t]", " ", "all").left(3000));
              inputs.data.worksauthorships.append(authorship.institutions[1].id);
              inputs.data.worksauthorships.append(
                authorship.raw_affiliation_string.reReplaceNoCase("[\n\r\t]", " ", "all").left(7000)
              );
              inputs.writer.worksauthorships.write(inputs.data.worksauthorships.toList(this.csvDelimiter));
              inputs.writer.worksauthorships.newLine();
              inputs.data.worksauthorships.clear();
            }
          }

          // best locations
          if (inputs.data.keyExists("worksbestoalocations")){
            if (line.keyExists("best_oa_location")){
              if (!line.best_oa_location.keyExists("license")){
                line.best_oa_location.license = "";
              }
              if (!line.best_oa_location.keyExists("version")){
                line.best_oa_location.version = "";
              }
              if (!line.best_oa_location.keyExists("landing_page_url")){
                line.best_oa_location.landing_page_url = "";
              }
              if (!line.best_oa_location.keyExists("pdf_url")){
                line.best_oa_location.pdf_url = "";
              }
              if (!line.best_oa_location.keyExists("source")){
                line.best_oa_location.source.id = "";
              }

              // unfortunately source_id can be blank, as well as landing_page_url or pdf_url.
              // if all 3 are blank, then there is no best_oa_location
              // creating a hash of the possible primary fields, to hopefully make it unique
              inputs.data.worksbestoalocations.append(
                hash(
                  line.id & line.best_oa_location.source.id & line.best_oa_location.landing_page_url & line.best_oa_location.pdf_url.reReplaceNoCase(
                    "[\n\r\t]",
                    " ",
                    "all"
                  ),
                  "MD5"
                )
              );
              inputs.data.worksbestoalocations.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksbestoalocations.append(arguments.snapshotMetaData.filenumber);
              inputs.data.worksbestoalocations.append(line.id);
              inputs.data.worksbestoalocations.append(line.best_oa_location.source.id);
              inputs.data.worksbestoalocations.append(line.best_oa_location.landing_page_url);
              inputs.data.worksbestoalocations.append(line.best_oa_location.pdf_url.reReplaceNoCase("[\n\r\t]", " ", "all"));
              (line.best_oa_location.is_oa) ? inputs.data.worksbestoalocations.append("1") : inputs.data.worksbestoalocations.append("0");
              inputs.data.worksbestoalocations.append(line.best_oa_location.version);
              inputs.data.worksbestoalocations.append(line.best_oa_location.license);

              inputs.writer.worksbestoalocations.write(inputs.data.worksbestoalocations.toList(this.csvDelimiter));
              inputs.writer.worksbestoalocations.newLine();
              inputs.data.worksbestoalocations.clear();
            }
          }

          // biblio
          if (inputs.data.keyExists("worksbiblio")){
            if (line.keyExists("biblio")){
              if (!line.biblio.keyExists("volume")){
                line.biblio.volume = "";
              }
              if (!line.biblio.keyExists("issue")){
                line.biblio.issue = "";
              }
              if (!line.biblio.keyExists("first_page")){
                line.biblio.first_page = "";
              }
              if (!line.biblio.keyExists("last_page")){
                line.biblio.last_page = "";
              }

              if (!(line.biblio.volume == "" && line.biblio.issue == "")){
                inputs.data.worksbiblio.append(line.id);
                inputs.data.worksbiblio.append(arguments.snapshotMetaData.updateDate);
                inputs.data.worksbiblio.append(arguments.snapshotMetaData.filenumber);
                inputs.data.worksbiblio.append(line.biblio.volume);
                inputs.data.worksbiblio.append(line.biblio.issue.left(100));
                inputs.data.worksbiblio.append(line.biblio.first_page.left(100));
                inputs.data.worksbiblio.append(line.biblio.last_page.left(100));

                inputs.writer.worksbiblio.write(inputs.data.worksbiblio.toList(this.csvDelimiter));
                inputs.writer.worksbiblio.newLine();
                inputs.data.worksbiblio.clear();
              }
            }
          }

          // concept
          if (inputs.data.keyExists("worksconcepts")){
            for (var concept in line.concepts){
              inputs.data.worksconcepts.append(line.id);
              inputs.data.worksconcepts.append(concept.id);
              inputs.data.worksconcepts.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksconcepts.append(arguments.snapshotMetaData.filenumber);
              inputs.data.worksconcepts.append(concept.score);

              inputs.writer.worksconcepts.write(inputs.data.worksconcepts.toList(this.csvDelimiter));
              inputs.writer.worksconcepts.newLine();
              inputs.data.worksconcepts.clear();
            }
          }

          // works ids
          if (inputs.data.keyExists("worksids")){
            if (line.keyExists("ids")){
              if (!line.ids.keyExists("doi")){
                line.ids.doi = "";
              }
              if (!line.ids.keyExists("mag")){
                line.ids.mag = "";
              }
              if (!line.ids.keyExists("pmid")){
                line.ids.pmid = "";
              }
              if (!line.ids.keyExists("pmcid")){
                line.ids.pmcid = "";
              }

              inputs.data.worksids.append(line.id);
              inputs.data.worksids.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksids.append(arguments.snapshotMetaData.filenumber);
              inputs.data.worksids.append(line.ids.openalex);
              inputs.data.worksids.append(line.ids.doi);
              inputs.data.worksids.append(line.ids.mag);
              inputs.data.worksids.append(line.ids.pmid);
              inputs.data.worksids.append(line.ids.pmcid);

              inputs.writer.worksids.write(inputs.data.worksids.toList(this.csvDelimiter));
              inputs.writer.worksids.newLine();
              inputs.data.worksids.clear();
            }
          }

          // locations
          if (inputs.data.keyExists("workslocations")){
            for (var location in line.locations){
              if (!location.keyExists("source")){
                location.source.id = "";
              }
              if (!location.keyExists("landing_page_url")){
                location.landing_page_url = "";
              }
              if (!location.keyExists("pdf_url")){
                location.pdf_url = "";
              }
              if (!location.keyExists("version")){
                location.version = "";
              }
              if (!location.keyExists("license")){
                location.license = "";
              }

              // need every record unique and the data coming from OA isn't always
              inputs.data.workslocations.append(
                hash(
                  line.id & location.source.id & location.landing_page_url & location.pdf_url.reReplaceNoCase(
                    "[\n\r\t]",
                    " ",
                    "all"
                  ) & location.is_oa & location.version & location.license,
                  "MD5"
                )
              );
              inputs.data.workslocations.append(line.id);
              inputs.data.workslocations.append(location.source.id);
              inputs.data.workslocations.append(arguments.snapshotMetaData.updateDate);
              inputs.data.workslocations.append(arguments.snapshotMetaData.filenumber);
              inputs.data.workslocations.append(location.landing_page_url);
              inputs.data.workslocations.append(location.pdf_url);
              (location.is_oa) ? inputs.data.workslocations.append("1") : inputs.data.workslocations.append("0");
              inputs.data.workslocations.append(location.version);
              inputs.data.workslocations.append(location.license);

              inputs.writer.workslocations.write(inputs.data.workslocations.toList(this.csvDelimiter));
              inputs.writer.workslocations.newLine();
              inputs.data.workslocations.clear();
            }
          }

          // mesh
          if (inputs.data.keyExists("worksmesh")){
            for (var mesh in line.mesh){
              if (!mesh.keyExists("qualifier_name")){
                mesh.qualifier_name = "";
              }

              inputs.data.worksmesh.append(line.id);
              inputs.data.worksmesh.append(mesh.descriptor_ui & mesh.qualifier_ui);
              inputs.data.worksmesh.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksmesh.append(arguments.snapshotMetaData.filenumber);
              inputs.data.worksmesh.append(mesh.descriptor_ui);
              inputs.data.worksmesh.append(mesh.descriptor_name);
              inputs.data.worksmesh.append(mesh.qualifier_ui);
              inputs.data.worksmesh.append(mesh.qualifier_name);
              (mesh.is_major_topic) ? inputs.data.worksmesh.append("1") : inputs.data.worksmesh.append("0");

              inputs.writer.worksmesh.write(inputs.data.worksmesh.toList(this.csvDelimiter));
              inputs.writer.worksmesh.newLine();
              inputs.data.worksmesh.clear();
            }
          }

          // open access
          if (inputs.data.keyExists("worksopenaccess")){
            if (line.keyExists("open_access")){
              if (!line.open_access.keyExists("oa_url")){
                line.open_access.oa_url = "";
              }

              inputs.data.worksopenaccess.append(line.id);
              inputs.data.worksopenaccess.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksopenaccess.append(arguments.snapshotMetaData.filenumber);
              (line.open_access.is_oa) ? inputs.data.worksopenaccess.append("1") : inputs.data.worksopenaccess.append("0");
              inputs.data.worksopenaccess.append(line.open_access.oa_status);
              inputs.data.worksopenaccess.append(line.open_access.oa_url.reReplaceNoCase("[\n\r\t]", " ", "all"));
              (line.open_access.any_repository_has_fulltext) ? inputs.data.worksopenaccess.append("1") : inputs.data.worksopenaccess.append("0");

              inputs.writer.worksopenaccess.write(inputs.data.worksopenaccess.toList(this.csvDelimiter));
              inputs.writer.worksopenaccess.newLine();
              inputs.data.worksopenaccess.clear();
            }
          }

          // primary locations
          if (inputs.data.keyExists("worksprimarylocations")){
            if (line.keyExists("primary_location")){
              if (!line.primary_location.keyExists("source")){
                line.primary_location.source.id = "";
              }
              if (!line.primary_location.keyExists("landing_page_url")){
                line.primary_location.landing_page_url = "";
              }
              if (!line.primary_location.keyExists("pdf_url")){
                line.primary_location.pdf_url = "";
              }
              if (!line.primary_location.keyExists("version")){
                line.primary_location.version = "";
              }
              if (!line.primary_location.keyExists("license")){
                line.primary_location.license = "";
              }

              // unfortunately source_id can be blank, as well as landing_page_url or pdf_url.
              // if all 3 are blank, then there is no best_oa_location
              // creating a hash of the possible primary fields, to hopefully make it unique
              inputs.data.worksprimarylocations.append(
                hash(
                  line.id & line.primary_location.source.id & line.primary_location.landing_page_url & line.primary_location.pdf_url.reReplaceNoCase(
                    "[\n\r\t]",
                    " ",
                    "all"
                  ),
                  "MD5"
                )
              );
              inputs.data.worksprimarylocations.append(line.id);
              inputs.data.worksprimarylocations.append(line.primary_location.source.id);
              inputs.data.worksprimarylocations.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksprimarylocations.append(arguments.snapshotMetaData.filenumber);
              inputs.data.worksprimarylocations.append(line.primary_location.landing_page_url);
              inputs.data.worksprimarylocations.append(line.primary_location.pdf_url.reReplaceNoCase("[\n\r\t]", " ", "all"));
              (line.primary_location.is_oa) ? inputs.data.worksprimarylocations.append("1") : inputs.data.worksprimarylocations.append("0");
              inputs.data.worksprimarylocations.append(line.primary_location.version);
              inputs.data.worksprimarylocations.append(line.primary_location.license);

              inputs.writer.worksprimarylocations.write(inputs.data.worksprimarylocations.toList(this.csvDelimiter));
              inputs.writer.worksprimarylocations.newLine();
              inputs.data.worksprimarylocations.clear();
            }
          }

          // referenced
          if (inputs.data.keyExists("worksreferencedworks")){
            for (var referenced_work_id in line.referenced_works){
              inputs.data.worksReferencedWorks.append(line.id);
              inputs.data.worksReferencedWorks.append(referenced_work_id);
              inputs.data.worksReferencedWorks.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksReferencedWorks.append(arguments.snapshotMetaData.filenumber);

              inputs.writer.worksReferencedWorks.write(inputs.data.worksReferencedWorks.toList(this.csvDelimiter));
              inputs.writer.worksReferencedWorks.newLine();
              inputs.data.worksReferencedWorks.clear();
            }
          }

          // related
          if (inputs.data.keyExists("worksrelatedworks")){
            for (var related_work_id in line.related_works){
              inputs.data.worksRelatedWorks.append(line.id);
              inputs.data.worksRelatedWorks.append(related_work_id);
              inputs.data.worksRelatedWorks.append(arguments.snapshotMetaData.updateDate);
              inputs.data.worksRelatedWorks.append(arguments.snapshotMetaData.filenumber);

              inputs.writer.worksRelatedWorks.write(inputs.data.worksRelatedWorks.toList(this.csvDelimiter));
              inputs.writer.worksRelatedWorks.newLine();
              inputs.data.worksRelatedWorks.clear();
            }
          }

          // works topics
          if (inputs.data.keyExists("workstopics")){
            if (line.keyExists("topics")){
              for (var topic in line.topics){
                if (!topic.keyExists("subfield")){
                  topic.subfield.id = "";
                }
                if (!topic.keyExists("field")){
                  topic.field.id = "";
                }
                if (!topic.keyExists("domain")){
                  topic.domain.id = "";
                }

                inputs.data.workstopics.append(line.id);
                inputs.data.workstopics.append(topic.id);
                inputs.data.workstopics.append(arguments.snapshotMetaData.updateDate);
                inputs.data.workstopics.append(arguments.snapshotMetaData.filenumber);
                inputs.data.workstopics.append(topic.score);
                inputs.data.workstopics.append(topic.subfield.id);
                inputs.data.workstopics.append(topic.field.id);
                inputs.data.workstopics.append(topic.domain.id);

                inputs.writer.workstopics.write(inputs.data.workstopics.toList(this.csvDelimiter));
                inputs.writer.workstopics.newLine();
                inputs.data.workstopics.clear();
              }
            }
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "works error");
      }
      finally{
        fileClose(worksData);
        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }

    return result;
  }

  private any function processSourcesData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("sources");
        // Create a file object
        var sourcesData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;

        var line = {};

        // loop through rows of data
        while (!fileIsEOF(sourcesData)){
          line = fileReadLine(sourcesData).deserializeJSON();

          if (inputs.data.keyExists("sources")){
            if (!line.keyExists("issn_l")){
              line.issn_l = "";
            }
            if (!line.keyExists("issn")){
              line.issn = [];
            }
            if (!line.keyExists("host_organization")){
              line.host_organization = "";
            }
            if (!line.keyExists("homepage_url")){
              line.homepage_url = "";
            }

            // publishers
            inputs.data.sources.append(line.id);
            inputs.data.sources.append(arguments.snapshotMetaData.updateDate);
            inputs.data.sources.append(arguments.snapshotMetaData.filenumber);
            inputs.data.sources.append(line.issn_l);
            (line.issn.isEmpty()) ? inputs.data.sources.append("") : inputs.data.sources.append(
              line.issn.slice(1, min(line.issn.len(), 100)).toJson()
            );
            inputs.data.sources.append(line.display_name); // todo: test
            inputs.data.sources.append(line.host_organization);
            inputs.data.sources.append(line.works_count);
            inputs.data.sources.append(line.cited_by_count);
            (line.is_oa) ? inputs.data.sources.append("1") : inputs.data.sources.append("0");
            (line.is_in_doaj) ? inputs.data.sources.append("1") : inputs.data.sources.append("0");
            inputs.data.sources.append(line.homepage_url);
            inputs.data.sources.append(line.works_api_url);
            inputs.data.sources.append(line.updated_date);
            inputs.writer.sources.write(inputs.data.sources.toList(this.csvDelimiter));
            inputs.writer.sources.newLine();
            inputs.data.sources.clear();
          }

          // counts
          if (inputs.data.keyExists("sourcescountsbyyear")){
            for (var counts in line.counts_by_year){
              if (!counts.keyExists("oa_works_count")){
                counts.oa_works_count = "";
              }

              inputs.data.sourcescountsbyyear.append(line.id);
              inputs.data.sourcescountsbyyear.append(counts.year);
              inputs.data.sourcescountsbyyear.append(arguments.snapshotMetaData.updateDate);
              inputs.data.sourcescountsbyyear.append(arguments.snapshotMetaData.filenumber);
              inputs.data.sourcescountsbyyear.append(counts.works_count);
              inputs.data.sourcescountsbyyear.append(counts.cited_by_count);
              inputs.data.sourcescountsbyyear.append(counts.oa_works_count);
              inputs.writer.sourcescountsbyyear.write(inputs.data.sourcescountsbyyear.toList(this.csvDelimiter));
              inputs.writer.sourcescountsbyyear.newLine();
              inputs.data.sourcescountsbyyear.clear();
            }
          }

          // ids
          if (inputs.data.keyExists("sourcesids")){
            if (!line.ids.keyExists("issn")){
              line.ids.issn = [];
            }
            if (!line.ids.keyExists("issn_l")){
              line.ids.issn_l = "";
            }
            if (!line.ids.keyExists("mag")){
              line.ids.mag = "";
            }
            if (!line.ids.keyExists("wikidata")){
              line.ids.wikidata = "";
            }
            if (!line.ids.keyExists("fatcat")){
              line.ids.fatcat = "";
            }

            inputs.data.sourcesids.append(line.id);
            inputs.data.sourcesids.append(arguments.snapshotMetaData.updateDate);
            inputs.data.sourcesids.append(arguments.snapshotMetaData.filenumber);
            inputs.data.sourcesids.append(line.ids.openalex);
            inputs.data.sourcesids.append(line.ids.issn_l);
            (line.issn.isEmpty()) ? inputs.data.sourcesids.append("") : inputs.data.sourcesids.append(
              line.issn.slice(1, min(line.issn.len(), 100)).toJson()
            );
            inputs.data.sourcesids.append(line.ids.mag);
            inputs.data.sourcesids.append(line.ids.wikidata);
            inputs.data.sourcesids.append(line.ids.fatcat);

            inputs.writer.sourcesids.write(inputs.data.sourcesids.toList(this.csvDelimiter));
            inputs.writer.sourcesids.newLine();
            inputs.data.sourcesids.clear();
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "source error");
      }
      finally{
        fileClose(sourcesData);

        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }
    return result;
  }

  private any function processPublishersData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("publishers");
        // Create a file object
        var publishersData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;

        var line = {};

        // loop through rows of data
        while (!fileIsEOF(publishersData)){
          line = fileReadLine(publishersData).deserializeJSON();

          if (inputs.data.keyExists("publishers")){
            if (!line.keyExists("parent_publisher")){
              line.parent_publisher.id = "";
            }
            if (!line.keyExists("homepage_url")){
              line.homepage_url = "";
            }
            if (!line.keyExists("image_url")){
              line.image_url = "";
            }
            if (!line.keyExists("image_thumbnail_url")){
              line.image_thumbnail_url = "";
            }

            // publishers
            inputs.data.publishers.append(line.id);
            inputs.data.publishers.append(arguments.snapshotMetaData.updateDate);
            inputs.data.publishers.append(arguments.snapshotMetaData.filenumber);
            inputs.data.publishers.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            (line.alternate_titles.isEmpty()) ? inputs.data.publishers.append("") : inputs.data.publishers.append(
              line.alternate_titles.slice(1, min(line.alternate_titles.len(), 100)).toJson()
            );
            (line.country_codes.isEmpty()) ? inputs.data.publishers.append("") : inputs.data.publishers.append(
              line.country_codes.slice(1, min(line.country_codes.len(), 100)).toJson()
            );
            inputs.data.publishers.append(line.hierarchy_level);
            inputs.data.publishers.append(line.parent_publisher.id);
            inputs.data.publishers.append(line.homepage_url);
            inputs.data.publishers.append(line.image_url);
            inputs.data.publishers.append(line.image_thumbnail_url);
            inputs.data.publishers.append(line.works_count);
            inputs.data.publishers.append(line.cited_by_count);
            inputs.data.publishers.append(line.sources_api_url);
            inputs.data.publishers.append(line.updated_date);

            inputs.writer.publishers.write(inputs.data.publishers.toList(this.csvDelimiter));
            inputs.writer.publishers.newLine();
            inputs.data.publishers.clear();
          }

          // counts
          if (inputs.data.keyExists("publisherscountsbyyear")){
            for (var counts in line.counts_by_year){
              if (!counts.keyExists("oa_works_count")){
                counts.oa_works_count = "";
              }

              inputs.data.publisherscountsbyyear.append(line.id);
              inputs.data.publisherscountsbyyear.append(counts.year);
              inputs.data.publisherscountsbyyear.append(arguments.snapshotMetaData.updateDate);
              inputs.data.publisherscountsbyyear.append(arguments.snapshotMetaData.filenumber);
              inputs.data.publisherscountsbyyear.append(counts.works_count);
              inputs.data.publisherscountsbyyear.append(counts.cited_by_count);
              inputs.data.publisherscountsbyyear.append(counts.oa_works_count);
              inputs.writer.publisherscountsbyyear.write(inputs.data.publisherscountsbyyear.toList(this.csvDelimiter));
              inputs.writer.publisherscountsbyyear.newLine();
              inputs.data.publisherscountsbyyear.clear();
            }
          }

          // ids
          if (inputs.data.keyExists("publishersids")){
            if (!line.ids.keyExists("ror")){
              line.ids.ror = "";
            }
            if (!line.ids.keyExists("wikidata")){
              line.ids.wikidata = "";
            }

            inputs.data.publishersids.append(line.id);
            inputs.data.publishersids.append(arguments.snapshotMetaData.updateDate);
            inputs.data.publishersids.append(arguments.snapshotMetaData.filenumber);
            inputs.data.publishersids.append(line.ids.openalex);
            inputs.data.publishersids.append(line.ids.ror);
            inputs.data.publishersids.append(line.ids.wikidata);

            inputs.writer.publishersids.write(inputs.data.publishersids.toList(this.csvDelimiter));
            inputs.writer.publishersids.newLine();
            inputs.data.publishersids.clear();
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "publisher error");
      }
      finally{
        fileClose(publishersData);

        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }
    return result;
  }

  private any function processInstitutionsData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("institutions");
        // Create a file object
        var institutionsData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;

        var line = {};

        // loop through rows of data
        while (!fileIsEOF(institutionsData)){
          line = fileReadLine(institutionsData).deserializeJSON();

          if (inputs.data.keyExists("institutions")){
            if (!line.keyExists("ror")){
              line.ror = "";
            }
            if (!line.keyExists("country_code")){
              line.country_code = "";
            }
            if (!line.keyExists("type")){
              line.type = "";
            }
            if (!line.keyExists("homepage_url")){
              line.homepage_url = "";
            }
            if (!line.keyExists("image_url")){
              line.image_url = "";
            }
            if (!line.keyExists("image_thumbnail_url")){
              line.image_thumbnail_url = "";
            }

            // insitutions
            inputs.data.institutions.append(line.id);
            inputs.data.institutions.append(arguments.snapshotMetaData.updateDate);
            inputs.data.institutions.append(arguments.snapshotMetaData.filenumber);
            inputs.data.institutions.append(line.ror);
            inputs.data.institutions.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            inputs.data.institutions.append(line.country_code);
            inputs.data.institutions.append(line.type);
            inputs.data.institutions.append(line.homepage_url);
            inputs.data.institutions.append(line.image_url);
            inputs.data.institutions.append(line.image_thumbnail_url);
            (line.display_name_acronyms.isEmpty()) ? inputs.data.institutions.append("") : inputs.data.institutions.append(
              line.display_name_acronyms.splice(1, min(line.display_name_acronyms.len(), 100)).toJson()
            );
            (line.display_name_alternatives.isEmpty()) ? inputs.data.institutions.append("") : inputs.data.institutions.append(
              line.display_name_alternatives.slice(1, min(line.display_name_alternatives.len(), 100)).toJson()
            );
            inputs.data.institutions.append(line.works_count);
            inputs.data.institutions.append(line.cited_by_count);
            inputs.data.institutions.append(line.works_api_url);
            inputs.data.institutions.append(line.updated_date);

            inputs.writer.institutions.write(inputs.data.institutions.toList(this.csvDelimiter));
            inputs.writer.institutions.newLine();
            inputs.data.institutions.clear();
          }

          // institutions associated
          if (inputs.data.keyExists("institutionsassociatedinstitutions")){
            for (var association in line.associated_institutions){
              inputs.data.institutionsassociatedinstitutions.append(line.id);
              inputs.data.institutionsassociatedinstitutions.append(association.id);
              inputs.data.institutionsassociatedinstitutions.append(arguments.snapshotMetaData.updateDate);
              inputs.data.institutionsassociatedinstitutions.append(arguments.snapshotMetaData.filenumber);
              inputs.data.institutionsassociatedinstitutions.append(association.relationship);

              inputs.writer.institutionsassociatedinstitutions.write(
                inputs.data.institutionsassociatedinstitutions.toList(this.csvDelimiter)
              );
              inputs.writer.institutionsassociatedinstitutions.newLine();
              inputs.data.institutionsassociatedinstitutions.clear();
            }
          }

          // institutions counts
          if (inputs.data.keyExists("institutionscountsbyyear")){
            for (var counts in line.counts_by_year){
              if (!counts.keyExists("oa_works_count")){
                counts.oa_works_count = "";
              }

              inputs.data.institutionscountsbyyear.append(line.id);
              inputs.data.institutionscountsbyyear.append(counts.year);
              inputs.data.institutionscountsbyyear.append(arguments.snapshotMetaData.updateDate);
              inputs.data.institutionscountsbyyear.append(arguments.snapshotMetaData.filenumber);
              inputs.data.institutionscountsbyyear.append(counts.works_count);
              inputs.data.institutionscountsbyyear.append(counts.cited_by_count);
              inputs.data.institutionscountsbyyear.append(counts.oa_works_count);
              inputs.writer.institutionscountsbyyear.write(inputs.data.institutionscountsbyyear.toList(this.csvDelimiter));
              inputs.writer.institutionscountsbyyear.newLine();
              inputs.data.institutionscountsbyyear.clear();
            }
          }

          // institutions geo
          if (inputs.data.keyExists("institutionsgeo")){
            if (!line.geo.keyExists("city")){
              line.geo.city = "";
            }
            if (!line.geo.keyExists("geonames_city_id")){
              line.geo.geonames_city_id = "";
            }
            if (!line.geo.keyExists("region")){
              line.geo.region = "";
            }
            if (!line.geo.keyExists("country_code")){
              line.geo.country_code = "";
            }
            if (!line.geo.keyExists("country")){
              line.geo.country = "";
            }
            if (!line.geo.keyExists("latitude")){
              line.geo.latitude = "";
            }
            if (!line.geo.keyExists("longitude")){
              line.geo.longitude = "";
            }

            inputs.data.institutionsgeo.append(line.id);
            inputs.data.institutionsgeo.append(arguments.snapshotMetaData.updateDate);
            inputs.data.institutionsgeo.append(arguments.snapshotMetaData.filenumber);
            inputs.data.institutionsgeo.append(line.geo.city);
            inputs.data.institutionsgeo.append(line.geo.geonames_city_id);
            inputs.data.institutionsgeo.append(line.geo.region);
            inputs.data.institutionsgeo.append(line.geo.country_code);
            inputs.data.institutionsgeo.append(line.geo.country);
            inputs.data.institutionsgeo.append(line.geo.latitude);
            inputs.data.institutionsgeo.append(line.geo.longitude);
            inputs.writer.institutionsgeo.write(inputs.data.institutionsgeo.toList(this.csvDelimiter));
            inputs.writer.institutionsgeo.newLine();
            inputs.data.institutionsgeo.clear();
          }

          // institutions ids
          if (inputs.data.keyExists("institutionsids")){
            if (!line.ids.keyExists("ror")){
              line.ids.ror = "";
            }
            if (!line.ids.keyExists("mag")){
              line.ids.mag = "";
            }
            if (!line.ids.keyExists("grid")){
              line.ids.grid = "";
            }
            if (!line.ids.keyExists("wikipedia")){
              line.ids.wikipedia = "";
            }
            if (!line.ids.keyExists("wikidata")){
              line.ids.wikidata = "";
            }

            inputs.data.institutionsids.append(line.id);
            inputs.data.institutionsids.append(arguments.snapshotMetaData.updateDate);
            inputs.data.institutionsids.append(arguments.snapshotMetaData.filenumber);
            inputs.data.institutionsids.append(line.ids.openalex);
            inputs.data.institutionsids.append(line.ids.ror);
            inputs.data.institutionsids.append(line.ids.grid);
            inputs.data.institutionsids.append(line.ids.wikipedia);
            inputs.data.institutionsids.append(line.ids.wikidata);
            inputs.data.institutionsids.append(line.ids.mag);

            inputs.writer.institutionsids.write(inputs.data.institutionsids.toList(this.csvDelimiter));
            inputs.writer.institutionsids.newLine();
            inputs.data.institutionsids.clear();
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "works error");
      }
      finally{
        fileClose(institutionsData);

        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }
    return result;
  }

  private any function processDomainsData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("domains");

        // Create a file object
        var domainsData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;
        // holds single row of data to process
        var line = {};

        // loop through rows of data
        while (!fileIsEOF(domainsData)){
          line = fileReadLine(domainsData).deserializeJSON();
          if (!line.keyExists("display_name_alternatives")){
            line.display_name_alternatives = [];
          }

          // domains
          if (inputs.data.keyExists("domains")){
            inputs.data.domains.append(line.id);
            inputs.data.domains.append(arguments.snapshotMetaData.updateDate);
            inputs.data.domains.append(arguments.snapshotMetaData.filenumber);
            inputs.data.domains.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            (line.display_name_alternatives.isEmpty()) ? inputs.data.domains.append("") : inputs.data.domains.append(
              line.display_name_alternatives.slice(1, min(line.display_name_alternatives.len(), 100)).toJson()
            );
            inputs.data.domains.append(line.description);
            inputs.data.domains.append(line.works_count);
            inputs.data.domains.append(line.cited_by_count);
            inputs.data.domains.append(line.works_api_url);
            inputs.data.domains.append(line.updated_date);

            inputs.writer.domains.write(inputs.data.domains.toList(this.csvDelimiter));
            inputs.writer.domains.newLine();
            inputs.data.domains.clear();
          }

          // domains ids
          if (inputs.data.keyExists("domainsids")){
            if (line.keyExists("ids")){
              inputs.data.domainsids.append(line.id);
              inputs.data.domainsids.append(arguments.snapshotMetaData.updateDate);
              inputs.data.domainsids.append(arguments.snapshotMetaData.filenumber);
              inputs.data.domainsids.append(line.ids.wikidata);
              inputs.data.domainsids.append(line.ids.wikipedia);

              inputs.writer.domainsids.write(inputs.data.domainsids.toList(this.csvDelimiter));
              inputs.writer.domainsids.newLine();
              inputs.data.domainsids.clear();
            }
          }

          // domains siblings
          if (inputs.data.keyExists("domainssiblings")){
            if (line.keyExists("siblings")){
              for (var sibling in line.siblings){
                inputs.data.domainssiblings.append(line.id);
                inputs.data.domainssiblings.append(sibling.id);
                inputs.data.domainssiblings.append(arguments.snapshotMetaData.updateDate);
                inputs.data.domainssiblings.append(arguments.snapshotMetaData.filenumber);

                inputs.writer.domainssiblings.write(inputs.data.domainssiblings.toList(this.csvDelimiter));
                inputs.writer.domainssiblings.newLine();
                inputs.data.domainssiblings.clear();
              }
            }
          }

          // domains fields
          if (inputs.data.keyExists("domainsfields")){
            if (line.keyExists("fields")){
              for (var field in line.fields){
                inputs.data.domainsfields.append(line.id);
                inputs.data.domainsfields.append(field.id);
                inputs.data.domainsfields.append(arguments.snapshotMetaData.updateDate);
                inputs.data.domainsfields.append(arguments.snapshotMetaData.filenumber);

                inputs.writer.domainsfields.write(inputs.data.domainsfields.toList(this.csvDelimiter));
                inputs.writer.domainsfields.newLine();
                inputs.data.domainsfields.clear();
              }
            }
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "domains error");
      }
      finally{
        fileClose(domainsData);
        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }

    return result;
  }

  private any function processFieldsData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("fields");

        // Create a file object
        var fieldsData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;
        // holds single row of data to process
        var line = {};

        // loop through rows of data
        while (!fileIsEOF(fieldsData)){
          line = fileReadLine(fieldsData).deserializeJSON();
          if (!line.keyExists("display_name_alternatives")){
            line.display_name_alternatives = [];
          }

          // fields
          if (inputs.data.keyExists("fields")){
            inputs.data.fields.append(line.id);
            inputs.data.fields.append(arguments.snapshotMetaData.updateDate);
            inputs.data.fields.append(arguments.snapshotMetaData.filenumber);
            inputs.data.fields.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            (line.display_name_alternatives.isEmpty()) ? inputs.data.fields.append("") : inputs.data.fields.append(
              line.display_name_alternatives.slice(1, min(line.display_name_alternatives.len(), 100)).toJson()
            );
            inputs.data.fields.append(line.description);
            inputs.data.fields.append(line.domain.id);
            inputs.data.fields.append(line.works_count);
            inputs.data.fields.append(line.cited_by_count);
            inputs.data.fields.append(line.works_api_url);
            inputs.data.fields.append(line.updated_date);

            inputs.writer.fields.write(inputs.data.fields.toList(this.csvDelimiter));
            inputs.writer.fields.newLine();
            inputs.data.fields.clear();
          }

          // fields ids
          if (inputs.data.keyExists("fieldsids")){
            if (line.keyExists("ids")){
              inputs.data.fieldsids.append(line.id);
              inputs.data.fieldsids.append(arguments.snapshotMetaData.updateDate);
              inputs.data.fieldsids.append(arguments.snapshotMetaData.filenumber);
              inputs.data.fieldsids.append(line.ids.wikidata);
              inputs.data.fieldsids.append(line.ids.wikipedia);

              inputs.writer.fieldsids.write(inputs.data.fieldsids.toList(this.csvDelimiter));
              inputs.writer.fieldsids.newLine();
              inputs.data.fieldsids.clear();
            }
          }

          // subfields siblings
          if (inputs.data.keyExists("fieldssiblings")){
            if (line.keyExists("siblings")){
              for (var sibling in line.siblings){
                inputs.data.fieldssiblings.append(line.id);
                inputs.data.fieldssiblings.append(sibling.id);
                inputs.data.fieldssiblings.append(arguments.snapshotMetaData.updateDate);
                inputs.data.fieldssiblings.append(arguments.snapshotMetaData.filenumber);

                inputs.writer.fieldssiblings.write(inputs.data.fieldssiblings.toList(this.csvDelimiter));
                inputs.writer.fieldssiblings.newLine();
                inputs.data.fieldssiblings.clear();
              }
            }
          }

          // fields subfields
          if (inputs.data.keyExists("fieldssubfields")){
            if (line.keyExists("topics")){
              for (var subfield in line.subfields){
                inputs.data.fieldssubfields.append(line.id);
                inputs.data.fieldssubfields.append(subfield.id);
                inputs.data.fieldssubfields.append(arguments.snapshotMetaData.updateDate);
                inputs.data.fieldssubfields.append(arguments.snapshotMetaData.filenumber);

                inputs.writer.fieldssubfields.write(inputs.data.fieldssubfields.toList(this.csvDelimiter));
                inputs.writer.fieldssubfields.newLine();
                inputs.data.fieldssubfields.clear();
              }
            }
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "fields error");
      }
      finally{
        fileClose(fieldsData);
        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }

    return result;
  }

  private any function processFundersData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("funders");
        // Create a file object
        var fundersData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;

        var line = {};

        // loop through rows of data
        while (!fileIsEOF(fundersData)){
          line = fileReadLine(fundersData).deserializeJSON();

          // funders
          if (inputs.data.keyExists("funders")){
            if (!line.keyExists("description")){
              line.description = "";
            }
            if (!line.keyExists("homepage_url")){
              line.homepage_url = "";
            }
            if (!line.keyExists("image_url")){
              line.image_url = "";
            }
            if (!line.keyExists("image_thumbnail_url")){
              line.image_thumbnail_url = "";
            }
            if (!line.keyExists("country_code")){
              line.country_code = "";
            }

            inputs.data.funders.append(line.id);
            inputs.data.funders.append(arguments.snapshotMetaData.updateDate);
            inputs.data.funders.append(arguments.snapshotMetaData.filenumber);
            inputs.data.funders.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            (line.alternate_titles.isEmpty()) ? inputs.data.funders.append("") : inputs.data.funders.append(
              line.alternate_titles.slice(1, min(line.alternate_titles.len(), 100)).toJson()
            );
            inputs.data.funders.append(line.country_code);
            inputs.data.funders.append(line.description.reReplaceNoCase("[\n\r\t]", " ", "all"));
            inputs.data.funders.append(line.homepage_url);
            inputs.data.funders.append(line.image_url);
            inputs.data.funders.append(line.image_thumbnail_url);
            inputs.data.funders.append(line.grants_count);
            inputs.data.funders.append(line.works_count);
            inputs.data.funders.append(line.cited_by_count);
            inputs.data.funders.append(line.updated_date);

            inputs.writer.funders.write(inputs.data.funders.toList(this.csvDelimiter));
            inputs.writer.funders.newLine();
            inputs.data.funders.clear();
          }

          // funders counts
          if (inputs.data.keyExists("funderscountsbyyear")){
            for (var counts in line.counts_by_year){
              inputs.data.funderscountsbyyear.append(line.id);
              inputs.data.funderscountsbyyear.append(counts.year);
              inputs.data.funderscountsbyyear.append(arguments.snapshotMetaData.updateDate);
              inputs.data.funderscountsbyyear.append(arguments.snapshotMetaData.filenumber);
              inputs.data.funderscountsbyyear.append(counts.works_count);
              inputs.data.funderscountsbyyear.append(counts.cited_by_count);

              inputs.writer.funderscountsbyyear.write(inputs.data.funderscountsbyyear.toList(this.csvDelimiter));
              inputs.writer.funderscountsbyyear.newLine();
              inputs.data.funderscountsbyyear.clear();
            }
          }

          // Ids
          if (inputs.data.keyExists("fundersids")){
            if (!line.ids.keyExists("ror")){
              line.ids.ror = "";
            }
            if (!line.ids.keyExists("wikidata")){
              line.ids.wikidata = "";
            }
            if (!line.ids.keyExists("crossref")){
              line.ids.crossref = "";
            }
            if (!line.ids.keyExists("doi")){
              line.ids.doi = "";
            }

            inputs.data.fundersids.append(line.id);
            inputs.data.fundersids.append(arguments.snapshotMetaData.updateDate);
            inputs.data.fundersids.append(arguments.snapshotMetaData.filenumber);
            inputs.data.fundersids.append(line.ids.openalex);
            inputs.data.fundersids.append(line.ids.ror);
            inputs.data.fundersids.append(line.ids.wikidata);
            inputs.data.fundersids.append(line.ids.crossref);
            inputs.data.fundersids.append(line.ids.doi);

            inputs.writer.fundersids.write(inputs.data.fundersids.toList(this.csvDelimiter));
            inputs.writer.fundersids.newLine();
            inputs.data.fundersids.clear();
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "works error");
      }
      finally{
        fileClose(fundersData);

        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }
    return result;
  }

  private any function processAuthorsData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("authors");
        // Create a file object
        var authorsData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;

        var line = {};

        // loop through rows of data
        while (!fileIsEOF(authorsData)){
          line = fileReadLine(authorsData).deserializeJSON();
          // writeDump(var=line,abort=true,label="");


          if (inputs.data.keyExists("authors")){
            if (!line.keyExists("orcid")){
              line.orcid = "";
            }
            if (!line.keyExists("last_known_insitution")){
              line.last_known_insitution.id = "";
            }

            // AUTHORS
            inputs.data.authors.append(line.id);
            inputs.data.authors.append(arguments.snapshotMetaData.updateDate);
            inputs.data.authors.append(arguments.snapshotMetaData.filenumber);
            inputs.data.authors.append(line.orcid);
            inputs.data.authors.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            (line.display_name_alternatives.isEmpty()) ? inputs.data.authors.append("") : inputs.data.authors.append(
              line.display_name_alternatives.slice(1, min(line.display_name_alternatives.len(), 100)).toJson()
            );
            inputs.data.authors.append(line.works_count);
            inputs.data.authors.append(line.cited_by_count);
            inputs.data.authors.append(line.last_known_insitution.id);
            inputs.data.authors.append(line.works_api_url);
            inputs.data.authors.append(line.updated_date);

            inputs.writer.authors.write(inputs.data.authors.toList(this.csvDelimiter));
            inputs.writer.authors.newLine();
            inputs.data.authors.clear();
          }

          // authors affiliations
          if (inputs.data.keyExists("authorsaffiliations")){
            if (line.keyExists("affiliations")){
              for (var affiliation in line.affiliations){
                for (var year in affiliation.years){
                  inputs.data.authorsaffiliations.append(line.id);
                  inputs.data.authorsaffiliations.append(affiliation.institution.id);
                  inputs.data.authorsaffiliations.append(year);
                  inputs.data.authorsaffiliations.append(arguments.snapshotMetaData.updateDate);
                  inputs.data.authorsaffiliations.append(arguments.snapshotMetaData.filenumber);
                  inputs.writer.authorsaffiliations.write(inputs.data.authorsaffiliations.toList(this.csvDelimiter));
                  inputs.writer.authorsaffiliations.newLine();
                  inputs.data.authorsaffiliations.clear();
                }
              }
            }
          }

          // authors last known institutions
          if (inputs.data.keyExists("authorslastinstitutions")){
            if (line.keyExists("last_known_institutions")){
              for (var lastknown in line.last_known_institutions){
                inputs.data.authorslastinstitutions.append(line.id);
                inputs.data.authorslastinstitutions.append(lastknown.id);
                inputs.data.authorslastinstitutions.append(arguments.snapshotMetaData.updateDate);
                inputs.data.authorslastinstitutions.append(arguments.snapshotMetaData.filenumber);
                inputs.writer.authorslastinstitutions.write(inputs.data.authorslastinstitutions.toList(this.csvDelimiter));
                inputs.writer.authorslastinstitutions.newLine();
                inputs.data.authorslastinstitutions.clear();
              }
            }
          }

          // AUTHORSCOUNTS
          if (inputs.data.keyExists("authorscountsbyyear")){
            for (var counts in line.counts_by_year){
              inputs.data.authorscountsbyyear.append(line.id);
              inputs.data.authorscountsbyyear.append(counts.year);
              inputs.data.authorscountsbyyear.append(arguments.snapshotMetaData.updateDate);
              inputs.data.authorscountsbyyear.append(arguments.snapshotMetaData.filenumber);
              inputs.data.authorscountsbyyear.append(counts.works_count);
              inputs.data.authorscountsbyyear.append(counts.cited_by_count);
              inputs.data.authorscountsbyyear.append(counts.oa_works_count);

              inputs.writer.authorscountsbyyear.write(inputs.data.authorscountsbyyear.toList(this.csvDelimiter));
              inputs.writer.authorscountsbyyear.newLine();
              inputs.data.authorscountsbyyear.clear();
            }
          }

          // Ids
          if (inputs.data.keyExists("authorsids")){
            if (!line.ids.keyExists("orcid")){
              line.ids.orcid = "";
            }
            if (!line.ids.keyExists("scopus")){
              line.ids.scopus = "";
            }
            if (!line.ids.keyExists("twitter")){
              line.ids.twitter = "";
            }
            if (!line.ids.keyExists("wikipedia")){
              line.ids.wikipedia = "";
            }
            if (!line.ids.keyExists("mag")){
              line.ids.mag = "";
            }

            inputs.data.authorsids.append(line.id);
            inputs.data.authorsids.append(arguments.snapshotMetaData.updateDate);
            inputs.data.authorsids.append(arguments.snapshotMetaData.filenumber);
            inputs.data.authorsids.append(line.ids.openalex);
            inputs.data.authorsids.append(line.ids.orcid);
            inputs.data.authorsids.append(line.ids.scopus);
            inputs.data.authorsids.append(line.ids.twitter);
            inputs.data.authorsids.append(line.ids.wikipedia);
            inputs.data.authorsids.append(line.ids.mag);

            inputs.writer.authorsids.write(inputs.data.authorsids.toList(this.csvDelimiter));
            inputs.writer.authorsids.newLine();
            inputs.data.authorsids.clear();
          }

          // AUTHORS Concepts
          if (inputs.data.keyExists("authorsconcepts")){
            if (line.keyExists("x_concepts")){
              for (var concepts in line.x_concepts){
                inputs.data.authorsconcepts.append(line.id);
                inputs.data.authorsconcepts.append(concepts.id);
                inputs.data.authorsconcepts.append(arguments.snapshotMetaData.updateDate);
                inputs.data.authorsconcepts.append(arguments.snapshotMetaData.filenumber);
                inputs.data.authorsconcepts.append(concepts.score);

                inputs.writer.authorsconcepts.write(inputs.data.authorsconcepts.toList(this.csvDelimiter));
                inputs.writer.authorsconcepts.newLine();
                inputs.data.authorsconcepts.clear();
              }
            }
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "authors error");
      }
      finally{
        fileClose(authorsData);
        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }
        result.success = true;
      }
    }
    return result;
  }

  private any function processConceptsData(snapshotfile, snapshotMetaData){
    var result = {success: false};

    var javaSystem = createObject("java", "java.lang.System");

    if (arguments.snapshotfile.success){
      try{
        var inputs = setupEntityCSVFiles("concepts");

        // Create a file object
        var conceptsData = fileOpen(arguments.snapshotfile.filepath, "read");

        var flushCounter = 0;
        var counter = 0;

        var line = {};

        // loop through rows of data
        while (!fileIsEOF(conceptsData)){
          line = fileReadLine(conceptsData).deserializeJSON();

          if (inputs.data.keyExists("concepts")){
            if (!line.keyExists("description")){
              line.description = "";
            }
            if (!line.keyExists("image_url")){
              line.image_url = "";
            }
            if (!line.keyExists("image_thumbnail_url")){
              line.image_thumbnail_url = "";
            }

            // Concepts
            inputs.data.concepts.append(line.id);
            inputs.data.concepts.append(arguments.snapshotMetaData.updateDate);
            inputs.data.concepts.append(arguments.snapshotMetaData.filenumber);
            inputs.data.concepts.append(line.wikidata);
            inputs.data.concepts.append(line.display_name.reReplaceNoCase("[\n\r\t]", " ", "all"));
            inputs.data.concepts.append(line.level);
            inputs.data.concepts.append(line.description.reReplaceNoCase("[\n\r\t]", " ", "all"));
            inputs.data.concepts.append(line.works_count);
            inputs.data.concepts.append(line.cited_by_count);
            inputs.data.concepts.append(line.image_url);
            inputs.data.concepts.append(line.image_thumbnail_url);
            inputs.data.concepts.append(line.works_api_url);
            inputs.data.concepts.append(line.updated_date);

            inputs.writer.concepts.write(inputs.data.concepts.toList(this.csvDelimiter));
            inputs.writer.concepts.newLine();
            inputs.data.concepts.clear();
          }

          // Ancestors
          if (inputs.data.keyExists("conceptsancestors")){
            for (var ancestor in line.ancestors){
              inputs.data.conceptsancestors.append(line.id);
              inputs.data.conceptsancestors.append(ancestor.id);
              inputs.data.conceptsancestors.append(arguments.snapshotMetaData.updateDate);
              inputs.data.conceptsancestors.append(arguments.snapshotMetaData.filenumber);

              inputs.writer.conceptsancestors.write(inputs.data.conceptsancestors.toList(this.csvDelimiter));
              inputs.writer.conceptsancestors.newLine();
              inputs.data.conceptsancestors.clear();
            }
          }

          // Counts
          if (inputs.data.keyExists("conceptscountsbyyear")){
            for (var counts in line.counts_by_year){
              if (!counts.keyExists("oa_works_count")){
                counts.oa_works_count = "";
              }

              inputs.data.conceptscountsbyyear.append(line.id);
              inputs.data.conceptscountsbyyear.append(counts.year);
              inputs.data.conceptscountsbyyear.append(arguments.snapshotMetaData.updateDate);
              inputs.data.conceptscountsbyyear.append(arguments.snapshotMetaData.filenumber);
              inputs.data.conceptscountsbyyear.append(counts.works_count);
              inputs.data.conceptscountsbyyear.append(counts.cited_by_count);
              inputs.data.conceptscountsbyyear.append(counts.oa_works_count);
              inputs.writer.conceptscountsbyyear.write(inputs.data.conceptscountsbyyear.toList(this.csvDelimiter));
              inputs.writer.conceptscountsbyyear.newLine();
              inputs.data.conceptscountsbyyear.clear();
            }
          }

          // Ids
          if (inputs.data.keyExists("conceptsids")){
            if (!line.ids.keyExists("wikidata")){
              line.ids.wikidata = "";
            }
            if (!line.ids.keyExists("wikipedia")){
              line.ids.wikipedia = "";
            }
            if (!line.ids.keyExists("umls_aui")){
              line.ids.umls_aui = [];
            }
            if (!line.ids.keyExists("umls_cui")){
              line.ids.umls_cui = [];
            }
            if (!line.ids.keyExists("mag")){
              line.ids.mag = "";
            }

            inputs.data.conceptsids.append(line.id);
            inputs.data.conceptsids.append(arguments.snapshotMetaData.updateDate);
            inputs.data.conceptsids.append(arguments.snapshotMetaData.filenumber);
            inputs.data.conceptsids.append(line.ids.openalex);
            inputs.data.conceptsids.append(line.ids.wikidata);
            inputs.data.conceptsids.append(line.ids.wikipedia);
            (line.ids.umls_aui.isEmpty()) ? inputs.data.conceptsids.append("") : inputs.data.conceptsids.append(
              line.ids.umls_aui.slice(1, min(line.ids.umls_aui.len(), 100)).toJson()
            );
            (line.ids.umls_cui.isEmpty()) ? inputs.data.conceptsids.append("") : inputs.data.conceptsids.append(
              line.ids.umls_cui.slice(1, min(line.ids.umls_cui.len(), 100)).toJson()
            );
            inputs.data.conceptsids.append(line.ids.mag);

            inputs.writer.conceptsids.write(inputs.data.conceptsids.toList(this.csvDelimiter));
            inputs.writer.conceptsids.newLine();
            inputs.data.conceptsids.clear();
          }

          // Related
          if (inputs.data.keyExists("conceptsrelatedconcepts")){
            for (var related in line.related_concepts){
              inputs.data.conceptsrelatedconcepts.append(line.id);
              inputs.data.conceptsrelatedconcepts.append(related.id);
              inputs.data.conceptsrelatedconcepts.append(arguments.snapshotMetaData.updateDate);
              inputs.data.conceptsrelatedconcepts.append(arguments.snapshotMetaData.filenumber);
              inputs.data.conceptsrelatedconcepts.append(related.score);

              inputs.writer.conceptsrelatedconcepts.write(inputs.data.conceptsrelatedconcepts.toList(this.csvDelimiter));
              inputs.writer.conceptsrelatedconcepts.newLine();
              inputs.data.conceptsrelatedconcepts.clear();
            }
          }

          flushCounter++;
          if (flushCounter == this.getwriteFlushLimit()){
            counter = counter + this.getwriteFlushLimit();

            for (var name in inputs.writer){
              inputs.writer[name].flush();
            }

            // Reset the flushCounter
            flushCounter = 0;
          }
          line.clear();
        }
      }
      catch (any e){
        outputError("Error: #e.message#");
        writeDump(var = line, abort = false, label = "");
        writeDump(var = e, abort = true, label = "concepts error");
      }
      finally{
        fileClose(conceptsData);

        for (var name in inputs.writer){
          inputs.writer[name].close();
        }

        for (var csv in inputs.csv){
          outputSuccess("Finished saving #csv# file to #inputs.csv[csv]#");
        }

        result.success = true;
      }
    }
    return result;
  }

  /**
   * Helper function to route merging of entity data from stage to production
   *
   * @entity
   */
  private any function mergeEntityStageWithMain(entity){
    var result = {success: false};

    var parallel = 10;

    outputh3("Merge #arguments.entity# staging tables with their main tables");
    flush;

    switch (arguments.entity){
      case "authors":
        result = mergeAuthorsStageWithMain(parallel);
        break;
      case "concepts":
        result = mergeConceptsStageWithMain(parallel);
        break;
      case "domains":
        result = mergeDomainsStageWithMain(parallel);
        break;
      case "fields":
        result = mergeFieldsStageWithMain(parallel);
        break;
      case "funders":
        result = mergeFundersStageWithMain(parallel);
        break;
      case "institutions":
        result = mergeInstitutionsStageWithMain(parallel);
        break;
      case "publishers":
        result = mergePublishersStageWithMain(parallel);
        break;
      case "sources":
        result = mergeSourcesStageWithMain(parallel);
        break;
      case "subfields":
        result = mergeSubfieldsStageWithMain(parallel);
        break;
      case "topics":
        result = mergeTopicsStageWithMain(parallel);
        break;
      case "works":
        result = mergeWorksStageWithMain(parallel);
        break;
    }

    return result;
  }

  private any function mergeSubfieldsStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        subfields: {success: false, recordcount: 0},
        subfields_ids: {success: false, recordcount: 0},
        subfields_siblings: {success: false, recordcount: 0},
        subfields_topics: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("subfields");

    // subfields
    if (activeTables.listFind("subfields")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.subfields dest
    USING #getSchema()#.stage$subfields src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.display_name = src.display_name,
          dest.display_name_alternatives = src.display_name_alternatives,
          dest.description = src.description,
          dest.field_id = src.field_id,
          dest.domain_id = src.domain_id,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.works_api_url=src.works_api_url,
          dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, display_name, display_name_alternatives, description, field_id, domain_id, 
        works_count, cited_by_count, works_api_url, updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.display_name, src.display_name_alternatives, src.description, 
        src.field_id, src.domain_id, src.works_count, src.cited_by_count, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.subfields.success = true;
        result.data.subfields.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.subfields.recordcount# staging subfields records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // ids
    if (activeTables.listFind("subfieldsids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.subfields_ids dest
    USING #getSchema()#.stage$subfields_ids src
    ON (dest.subfield_id = src.subfield_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.wikidata=src.wikidata,
          dest.wikipedia=src.wikipedia
    WHEN NOT MATCHED THEN
        INSERT (subfield_id, snapshotdate, snapshotfilenumber, wikidata, wikipedia)
        VALUES (src.subfield_id, src.snapshotdate, src.snapshotfilenumber, src.wikidata, src.wikipedia)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.subfields_ids.success = true;
        result.data.subfields_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.subfields_ids.recordcount# staging subfields_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // siblings
    if (activeTables.listFind("subfieldssiblings")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.subfields_siblings dest
    USING #getSchema()#.stage$subfields_siblings src
    ON (dest.subfield_id = src.subfield_id AND dest.sibling_id = src.sibling_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber
    WHEN NOT MATCHED THEN
        INSERT (subfield_id, sibling_id, snapshotdate, snapshotfilenumber)
        VALUES (src.subfield_id, src.sibling_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.subfields_siblings.success = true;
        result.data.subfields_siblings.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.subfields_siblings.recordcount# staging subfields_siblings records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // subfields topics
    if (activeTables.listFind("subfieldstopics")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.subfields_topics dest
    USING #getSchema()#.stage$subfields_topics src
    ON (dest.subfield_id = src.subfield_id AND dest.topic_id = src.topic_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber
    WHEN NOT MATCHED THEN
        INSERT (subfield_id, topic_id, snapshotdate, snapshotfilenumber)
        VALUES (src.subfield_id, src.topic_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.subfields_topics.success = true;
        result.data.subfields_topics.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.subfields_topics.recordcount# staging subfields_topics records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeTopicsStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        topics: {success: false, recordcount: 0},
        topics_ids: {success: false, recordcount: 0},
        topics_siblings: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("topics");

    // topics
    if (activeTables.listFind("topics")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.topics dest
    USING #getSchema()#.stage$topics src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.display_name = src.display_name,
          dest.description = src.description,
          dest.keywords = src.keywords,
          dest.subfield_id = src.subfield_id,
          dest.field_id = src.field_id,
          dest.domain_id = src.domain_id,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, display_name, description, keywords, subfield_id, field_id, domain_id, 
        works_count, cited_by_count, updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.display_name, src.description, src.keywords, src.subfield_id, 
        src.field_id, src.domain_id, src.works_count, src.cited_by_count, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.topics.success = true;
        result.data.topics.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.topics.recordcount# staging topics records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // ids
    if (activeTables.listFind("topicsids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.topics_ids dest
    USING #getSchema()#.stage$topics_ids src
    ON (dest.topic_id = src.topic_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.openalex=src.openalex,
          dest.wikipedia=src.wikipedia
    WHEN NOT MATCHED THEN
        INSERT (topic_id, snapshotdate, snapshotfilenumber, openalex, wikipedia)
        VALUES (src.topic_id, src.snapshotdate, src.snapshotfilenumber, src.openalex, src.wikipedia)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.topics_ids.success = true;
        result.data.topics_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.topics_ids.recordcount# staging topics_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // siblings
    if (activeTables.listFind("topicssiblings")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.topics_siblings dest
    USING #getSchema()#.stage$topics_siblings src
    ON (dest.topic_id = src.topic_id AND dest.sibling_id = src.sibling_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber
    WHEN NOT MATCHED THEN
        INSERT (topic_id, sibling_id, snapshotdate, snapshotfilenumber)
        VALUES (src.topic_id, src.sibling_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.topics_siblings.success = true;
        result.data.topics_siblings.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.topics_siblings.recordcount# staging topics_siblings records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeWorksStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        works: {success: false, recordcount: 0},
        works_authorships: {success: false, recordcount: 0},
        works_best_oa_locations: {success: false, recordcount: 0},
        works_biblio: {success: false, recordcount: 0},
        works_concepts: {success: false, recordcount: 0},
        works_ids: {success: false, recordcount: 0},
        works_locations: {success: false, recordcount: 0},
        works_mesh: {success: false, recordcount: 0},
        works_open_access: {success: false, recordcount: 0},
        works_primary_locations: {success: false, recordcount: 0},
        works_referenced_works: {success: false, recordcount: 0},
        works_related_works: {success: false, recordcount: 0},
        works_topics: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("works");

    // works
    if (activeTables.listFind("works")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works dest
    USING #getSchema()#.stage$works src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.doi = src.doi,
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.title = src.title,
            dest.display_name = src.display_name,
            dest.publication_year = src.publication_year,
            dest.publication_date = src.publication_date,
            dest.type = src.type,
            dest.cited_by_count = src.cited_by_count,
            dest.is_retracted = src.is_retracted,
            dest.is_paratext = src.is_paratext,
            dest.cited_by_api_url = src.cited_by_api_url,
            -- dest.abstract_in,
            dest.language = src.language
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, doi, title, display_name, publication_year, publication_date, type, cited_by_count, is_retracted, is_paratext,
          cited_by_api_url, language)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.doi, src.title, src.display_name, src.publication_year, src.publication_date, src.type, src.cited_by_count, 
          src.is_retracted, src.is_paratext, src.cited_by_api_url, src.language)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works.success = true;
        result.data.works.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works.recordcount# staging works records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // authorships
    if (activeTables.listFind("worksauthorships")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_authorships dest
    USING (
      SELECT work_id, author_id, snapshotdate, snapshotfilenumber, author_position, raw_author_name, institution_id, raw_affiliation_string
        FROM (
            SELECT 
                work_id, 
                author_id, 
                snapshotdate,
                snapshotfilenumber,
                author_position, 
                raw_author_name, 
                institution_id, 
                raw_affiliation_string,
                ROW_NUMBER() OVER (PARTITION BY work_id, author_id ORDER BY work_id) AS rn
            FROM #getSchema()#.stage$works_authorships
        ) 
        WHERE rn = 1
    ) src
    ON (dest.work_id = src.work_id AND dest.author_id = src.author_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.author_position = src.author_position,
            dest.raw_author_name = src.raw_author_name,
            dest.raw_affiliation_string = src.raw_affiliation_string
    WHEN NOT MATCHED THEN
        INSERT (work_id, snapshotdate, snapshotfilenumber, author_position, author_id, raw_author_name, institution_id, raw_affiliation_string)
        VALUES (src.work_id, src.snapshotdate, src.snapshotfilenumber, src.author_position, src.author_id, src.raw_author_name, src.institution_id, src.raw_affiliation_string)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_authorships.success = true;
        result.data.works_authorships.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_authorships.recordcount# staging works_authorships records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // works_best_oa_locations
    if (activeTables.listFind("worksbestoalocations")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_best_oa_locations dest
    USING #getSchema()#.stage$works_best_oa_locations src
    ON (dest.work_id = src.work_id AND dest.source_id = src.source_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.landing_page_url = src.landing_page_url,
            dest.pdf_url = src.pdf_url,
            dest.is_oa = src.is_oa,
            dest.version = src.version,
            dest.license = src.license
    WHEN NOT MATCHED THEN
        INSERT (unique_id,snapshotdate, snapshotfilenumber, work_id, source_id, landing_page_url, pdf_url, is_oa, version, license)
        VALUES (src.unique_id,src.snapshotdate, src.snapshotfilenumber, src.work_id, src.source_id, src.landing_page_url, src.pdf_url, src.is_oa, src.version, src.license)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_best_oa_locations.success = true;
        result.data.works_best_oa_locations.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_best_oa_locations.recordcount# staging works_best_oa_locations records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // biblio
    if (activeTables.listFind("worksbiblio")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_biblio dest
    USING #getSchema()#.stage$works_biblio src
    ON (dest.work_id = src.work_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.volume = src.volume,
            dest.issue = src.issue,
            dest.first_page = src.first_page,
            dest.last_page = src.last_page
    WHEN NOT MATCHED THEN
        INSERT (work_id, snapshotdate, snapshotfilenumber, volume, issue, first_page, last_page)
        VALUES (src.work_id, src.snapshotdate, src.snapshotfilenumber, src.volume, src.issue, src.first_page, src.last_page)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_biblio.success = true;
        result.data.works_biblio.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_biblio.recordcount# staging works_biblio records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // concepts
    if (activeTables.listFind("worksconcepts")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_concepts dest
    USING #getSchema()#.stage$works_concepts src
    ON (dest.work_id = src.work_id AND dest.concept_id = src.concept_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.score = src.score
    WHEN NOT MATCHED THEN
        INSERT (work_id, concept_id, snapshotdate, snapshotfilenumber, score)
        VALUES (src.work_id, src.concept_id, src.snapshotdate, src.snapshotfilenumber, src.score)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_concepts.success = true;
        result.data.works_concepts.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_concepts.recordcount# staging works_concepts records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // ids
    if (activeTables.listFind("worksids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_ids dest
    USING #getSchema()#.stage$works_ids src
    ON (dest.work_id = src.work_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.openalex = src.openalex,
            dest.doi = src.doi,
            dest.mag = src.mag,
            dest.pmid = src.pmid,
            dest.pmcid = src.pmcid
    WHEN NOT MATCHED THEN
        INSERT (work_id, snapshotdate, snapshotfilenumber, openalex, doi, mag, pmid, pmcid)
        VALUES (src.work_id, src.snapshotdate, src.snapshotfilenumber, src.openalex, src.doi, src.mag, src.pmid, src.pmcid)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_ids.success = true;
        result.data.works_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_ids.recordcount# staging works_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // locations

    // I realize i'm filtering out additional records with this query
    // The data doesn't really have a great primary key
    // In order to not reduce the load time anymore I'm filtering on work_id and source_id
    // Loading via the append mode would result in the full location dataset if this data is important
    if (activeTables.listFind("workslocations")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_locations dest
    USING (
      SELECT UNIQUE_ID,WORK_ID,SOURCE_ID,SNAPSHOTDATE,SNAPSHOTFILENUMBER,LANDING_PAGE_URL,
      PDF_URL,IS_OA,VERSION,LICENSE
        FROM (
            SELECT UNIQUE_ID,WORK_ID,SOURCE_ID,SNAPSHOTDATE,SNAPSHOTFILENUMBER,LANDING_PAGE_URL,
            PDF_URL,IS_OA,VERSION,LICENSE,
            ROW_NUMBER() OVER (PARTITION BY WORK_ID,SOURCE_ID ORDER BY work_id) AS rn
            FROM #getSchema()#.STAGE$WORKS_LOCATIONS
        ) 
        WHERE rn = 1
    ) src
    ON (dest.work_id = src.work_id AND dest.source_id = src.source_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.landing_page_url = src.landing_page_url,
            dest.pdf_url = src.pdf_url,
            dest.is_oa = src.is_oa,
            dest.version = src.version,
            dest.license = src.license
    WHEN NOT MATCHED THEN
        INSERT (unique_id,snapshotdate, snapshotfilenumber, work_id, source_id, landing_page_url, pdf_url, is_oa, version, license)
        VALUES (src.unique_id,src.snapshotdate, src.snapshotfilenumber, src.work_id, src.source_id, src.landing_page_url, src.pdf_url, 
          src.is_oa, src.version, src.license)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_locations.success = true;
        result.data.works_locations.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_locations.recordcount# staging works_location records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // mesh
    if (activeTables.listFind("worksmesh")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_mesh dest
    USING #getSchema()#.stage$works_mesh src
    ON (dest.work_id = src.work_id AND dest.merge_id = src.merge_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.descriptor_ui = src.descriptor_ui,
            dest.descriptor_name = src.descriptor_name,
            dest.qualifier_ui = src.qualifier_ui,
            dest.qualifier_name = src.qualifier_name,
            dest.is_major_topic = src.is_major_topic
    WHEN NOT MATCHED THEN
        INSERT (merge_id, work_id, snapshotdate, snapshotfilenumber, descriptor_ui, descriptor_name, qualifier_ui, qualifier_name, is_major_topic)
        VALUES (src.merge_id, src.work_id, src.snapshotdate, src.snapshotfilenumber, src.descriptor_ui, src.descriptor_name, src.qualifier_ui, src.qualifier_name, src.is_major_topic)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_mesh.success = true;
        result.data.works_mesh.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_mesh.recordcount# staging works_mesh records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // open access
    if (activeTables.listFind("worksopenaccess")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_open_access dest
    USING #getSchema()#.stage$works_open_access src
    ON (dest.work_id = src.work_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.is_oa = src.is_oa,
            dest.oa_status = src.oa_status,
            dest.oa_url = src.oa_url,
            dest.any_repository_has_fulltext = src.any_repository_has_fulltext
    WHEN NOT MATCHED THEN
        INSERT (work_id, snapshotdate, snapshotfilenumber, is_oa, oa_status, oa_url, any_repository_has_fulltext)
        VALUES (src.work_id, src.snapshotdate, src.snapshotfilenumber, src.is_oa, src.oa_status, src.oa_url, src.any_repository_has_fulltext)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_open_access.success = true;
        result.data.works_open_access.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_open_access.recordcount# staging works_open_access records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // primary locations
    if (activeTables.listFind("worksprimarylocations")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_primary_locations dest
    USING #getSchema()#.stage$works_primary_locations src
    ON (dest.work_id = src.work_id AND dest.source_id = src.source_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.landing_page_url = src.landing_page_url,
            dest.pdf_url = src.pdf_url,
            dest.is_oa = src.is_oa,
            dest.version = src.version,
            dest.license = src.license
    WHEN NOT MATCHED THEN
        INSERT (unique_id,snapshotdate, snapshotfilenumber, work_id, source_id, landing_page_url, pdf_url, is_oa, version, license)
        VALUES (src.unique_id,src.snapshotdate, src.snapshotfilenumber, src.work_id, src.source_id, src.landing_page_url, src.pdf_url, 
          src.is_oa, src.version, src.license)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_primary_locations.success = true;
        result.data.works_primary_locations.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_primary_locations.recordcount# staging works_location records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // referenced
    if (activeTables.listFind("worksreferencedworks")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_referenced_works dest
    USING #getSchema()#.stage$works_referenced_works src
    ON (dest.work_id = src.work_id AND dest.referenced_work_id = src.referenced_work_id)
    WHEN NOT MATCHED THEN
        INSERT (work_id, referenced_work_id, snapshotdate, snapshotfilenumber)
        VALUES (src.work_id, src.referenced_work_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_referenced_works.success = true;
        result.data.works_referenced_works.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_referenced_works.recordcount# staging works_referenced_works records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // related
    if (activeTables.listFind("worksrelatedworks")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_related_works dest
    USING #getSchema()#.stage$works_related_works src
    ON (dest.work_id = src.work_id AND dest.related_work_id = src.related_work_id)
    WHEN NOT MATCHED THEN
        INSERT (work_id, related_work_id, snapshotdate, snapshotfilenumber)
        VALUES (src.work_id, src.related_work_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_related_works.success = true;
        result.data.works_related_works.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_related_works.recordcount# staging works_related_works records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // topics
    if (activeTables.listFind("workstopics")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_topics dest
        USING #getSchema()#.stage$works_topics src
        ON (dest.work_id = src.work_id AND dest.topic_id = src.topic_id)
        WHEN MATCHED THEN
            UPDATE SET
                dest.snapshotdate = src.snapshotdate,
                dest.snapshotfilenumber = src.snapshotfilenumber,
                dest.score = src.score,
                dest.subfield_id = src.subfield_id,
                dest.field_id = src.field_id,
                dest.domain_id = src.domain_id
        WHEN NOT MATCHED THEN
            INSERT (work_id,topic_id,snapshotdate, snapshotfilenumber, score,subfield_id,field_id,domain_id)
            VALUES (src.work_id,src.topic_id,src.snapshotdate,src.snapshotfilenumber,src.score,src.subfield_id,src.field_id,src.domain_id)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_topics.success = true;
        result.data.works_topics.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.works_topics.recordcount# staging works_topics records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeSourcesStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        sources: {success: false, recordcount: 0},
        sources_counts_by_year: {success: false, recordcount: 0},
        sources_ids: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("sources");

    // sources
    if (activeTables.listFind("sources")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.sources dest
    USING #getSchema()#.stage$sources src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.issn_l = src.issn_l,
          dest.issn = src.issn,
          dest.display_name = src.display_name,
          dest.publisher = src.publisher,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.is_oa=src.is_oa,
          dest.is_in_doaj=src.is_in_doaj,
          dest.homepage_url=src.homepage_url,
          dest.works_api_url=src.works_api_url,
          dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, issn_l, issn, display_name, publisher, works_count, cited_by_count, is_oa, is_in_doaj,
          homepage_url, works_api_url, updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.issn_l, src.issn, src.display_name, src.publisher, src.works_count, src.cited_by_count, src.is_oa, 
          src.is_in_doaj, src.homepage_url, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.sources.success = true;
        result.data.sources.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.sources.recordcount# staging sources records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // counts
    if (activeTables.listFind("sourcescountsbyyear")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.sources_counts_by_year dest
    USING #getSchema()#.stage$sources_counts_by_year src
    ON (dest.source_id = src.source_id AND dest.year = src.year)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.oa_works_count=src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (source_id, year, snapshotdate, snapshotfilenumber, works_count, cited_by_count, oa_works_count)
        VALUES (src.source_id, src.year, src.snapshotdate, src.snapshotfilenumber, src.works_count, src.cited_by_count, src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.sources_counts_by_year.success = true;
        result.data.sources_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.sources_counts_by_year.recordcount# staging sources_counts_by_year records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // ids
    if (activeTables.listFind("sourcesids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.sources_ids dest
    USING #getSchema()#.stage$sources_ids src
    ON (dest.source_id = src.source_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.openalex=src.openalex,
          dest.issn_l=src.issn_l,
          dest.issn=src.issn,
          dest.mag=src.mag,
          dest.wikidata=src.wikidata,
          dest.fatcat=src.fatcat
    WHEN NOT MATCHED THEN
        INSERT (source_id, openalex, issn_l, issn, mag, wikidata, fatcat)
        VALUES (src.source_id, src.openalex, src.issn_l, src.issn, src.mag, src.wikidata, src.fatcat)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.sources_ids.success = true;
        result.data.sources_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.sources_ids.recordcount# staging sources_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergePublishersStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        publishers: {success: false, recordcount: 0},
        publishers_counts_by_year: {success: false, recordcount: 0},
        publishers_ids: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("publishers");

    // publishers
    if (activeTables.listFind("publishers")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.publishers dest
    USING #getSchema()#.stage$publishers src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.display_name = src.display_name,
          dest.alternate_titles = src.alternate_titles,
          dest.country_codes = src.country_codes,
          dest.hierarchy_level=src.hierarchy_level,
          dest.parent_publisher=src.parent_publisher,
          dest.homepage_url=src.homepage_url,
          dest.image_url=src.image_url,
          dest.image_thumbnail_url=src.image_thumbnail_url,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.sources_api_url=src.sources_api_url,
          dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, display_name, alternate_titles, country_codes, hierarchy_level, parent_publisher, homepage_url,
        image_url,image_thumbnail_url,works_count, cited_by_count, sources_api_url, updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.display_name, src.alternate_titles, src.country_codes, src.hierarchy_level, src.parent_publisher, 
        src.homepage_url,src.image_url,src.image_thumbnail_url,src.works_count, src.cited_by_count, src.sources_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.publishers.success = true;
        result.data.publishers.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.publishers.recordcount# staging publishers records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // counts
    if (activeTables.listFind("publisherscountsbyyear")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.publishers_counts_by_year dest
    USING #getSchema()#.stage$publishers_counts_by_year src
    ON (dest.publisher_id = src.publisher_id AND dest.year = src.year)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.oa_works_count=src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (publisher_id, year, snapshotdate, snapshotfilenumber, works_count, cited_by_count, oa_works_count)
        VALUES (src.publisher_id, src.year, src.snapshotdate, src.snapshotfilenumber, src.works_count, src.cited_by_count, src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.publishers_counts_by_year.success = true;
        result.data.publishers_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.publishers_counts_by_year.recordcount# staging publishers_counts_by_year records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // ids
    if (activeTables.listFind("publishersids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.publishers_ids dest
    USING #getSchema()#.stage$publishers_ids src
    ON (dest.publisher_id = src.publisher_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.openalex=src.openalex,
          dest.ror=src.ror,
          dest.wikidata=src.wikidata
    WHEN NOT MATCHED THEN
        INSERT (publisher_id, snapshotdate, snapshotfilenumber, openalex, ror, wikidata)
        VALUES (src.publisher_id, src.snapshotdate, src.snapshotfilenumber, src.openalex, src.ror, src.wikidata)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.publishers_ids.success = true;
        result.data.publishers_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.publishers_ids.recordcount# staging publishers_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeInstitutionsStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        institutions: {success: false, recordcount: 0},
        institutions_associated_institutions: {success: false, recordcount: 0},
        institutions_counts_by_year: {success: false, recordcount: 0},
        institutions_geo: {success: false, recordcount: 0},
        institutions_ids: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("institutions");

    // institutions
    if (activeTables.listFind("institutions")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.institutions dest
        USING #getSchema()#.stage$institutions src
        ON (dest.id = src.id)
        WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.ror = src.ror,
          dest.display_name = src.display_name,
          dest.country_code = src.country_code,
          dest.type = src.type,
          dest.homepage_url=src.homepage_url,
          dest.image_url=src.image_url,
          dest.image_thumbnail_url=src.image_thumbnail_url,
          dest.display_name_acronyms=src.display_name_acronyms,
          dest.display_name_alternatives=src.display_name_alternatives,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.works_api_url=src.works_api_url,
          dest.updated_date=src.updated_date
        WHEN NOT MATCHED THEN
          INSERT (id, snapshotdate, snapshotfilenumber, ror, display_name, country_code, type, homepage_url, image_url, image_thumbnail_url, 
          display_name_acronyms,display_name_alternatives, works_count, cited_by_count, works_api_url, updated_date)
          VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.ror, src.display_name, src.country_code, src.type, src.homepage_url, src.image_url, src.image_thumbnail_url, 
          src.display_name_acronyms, src.display_name_alternatives, src.works_count, src.cited_by_count, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions.success = true;
        result.data.institutions.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.institutions.recordcount# staging institutions records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // associated institutions
    if (activeTables.listFind("institutionsassociatedinstitutions")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.institutions_associated_institutions dest
    USING #getSchema()#.stage$institutions_associated_institutions src
    ON (dest.institution_id = src.institution_id AND dest.associated_institution_id = src.associated_institution_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.relationship = src.relationship            
    WHEN NOT MATCHED THEN
        INSERT (institution_id, associated_institution_id, snapshotdate, snapshotfilenumber, relationship)
        VALUES (src.institution_id, src.associated_institution_id, src.snapshotdate, src.snapshotfilenumber, src.relationship)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions_associated_institutions.success = true;
        result.data.institutions_associated_institutions.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.institutions_associated_institutions.recordcount# staging institutions_associated_institutions records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // counts
    if (activeTables.listFind("institutionscountsbyyear")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.institutions_counts_by_year dest
    USING #getSchema()#.stage$institutions_counts_by_year src
    ON (dest.institution_id = src.institution_id AND dest.year = src.year)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.works_count = src.works_count,
            dest.cited_by_count = src.cited_by_count,
            dest.oa_works_count = src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (institution_id, year, snapshotdate, snapshotfilenumber, works_count, cited_by_count, oa_works_count)
        VALUES (src.institution_id, src.year, src.snapshotdate, src.snapshotfilenumber, src.works_count, src.cited_by_count, src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions_counts_by_year.success = true;
        result.data.institutions_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.institutions_counts_by_year.recordcount# staging institutions_counts_by_year records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // geo
    if (activeTables.listFind("institutionsgeo")){
      queryExecute(
        "MERGE INTO #getSchema()#.institutions_geo dest
    USING #getSchema()#.stage$institutions_geo src
    ON (dest.institution_id = src.institution_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.city = src.city,
            dest.geonames_city_id = src.geonames_city_id,
            dest.region = src.region,
            dest.country_code = src.country_code,
            dest.country = src.country,
            dest.latitude = src.latitude,
            dest.longitude = src.longitude
    WHEN NOT MATCHED THEN
        INSERT (institution_id, snapshotdate, snapshotfilenumber, city, geonames_city_id, region, country_code, country, latitude, longitude)
        VALUES (src.institution_id, src.snapshotdate, src.snapshotfilenumber, src.city, src.geonames_city_id, src.region, src.country_code, src.country, src.latitude, src.longitude)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions_geo.success = true;
        result.data.institutions_geo.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.institutions_geo.recordcount# staging institutions_geo records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // ids
    if (activeTables.listFind("institutionsids")){
      queryExecute(
        "MERGE INTO #getSchema()#.institutions_ids dest
    USING #getSchema()#.stage$institutions_ids src
    ON (dest.institution_id = src.institution_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.openalex = src.openalex,
            dest.ror = src.ror,
            dest.grid = src.grid,
            dest.wikipedia = src.wikipedia,
            dest.wikidata = src.wikidata,
            dest.mag = src.mag
    WHEN NOT MATCHED THEN
        INSERT (institution_id, snapshotdate, snapshotfilenumber, openalex, ror, grid, wikipedia, wikidata, mag)
        VALUES (src.institution_id, src.snapshotdate, src.snapshotfilenumber, src.openalex, src.ror, src.grid, src.wikipedia, src.wikidata, src.mag)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions_ids.success = true;
        result.data.institutions_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.institutions_ids.recordcount# staging institutions_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeConceptsStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        concepts: {success: false, recordcount: 0},
        concepts_ancestors: {success: false, recordcount: 0},
        concepts_counts_by_year: {success: false, recordcount: 0},
        concepts_ids: {success: false, recordcount: 0},
        concepts_related_concepts: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("concepts");

    // concepts
    if (activeTables.listFind("concepts")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.concepts dest
    USING #getSchema()#.stage$concepts src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.wikidata = src.wikidata,
            dest.display_name = src.display_name,
            dest.concept_level = src.concept_level,
            dest.description = src.description,
            dest.works_count=src.works_count,
            dest.cited_by_count=src.cited_by_count,
            dest.image_url=src.image_url,
            dest.image_thumbnail_url=src.image_thumbnail_url,
            dest.works_api_url=src.works_api_url,
            dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, wikidata, display_name, concept_level, description, works_count, cited_by_count,
          image_url, image_thumbnail_url, works_api_url, updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.wikidata, src.display_name, src.concept_level, src.description, src.works_count, src.cited_by_count,
        src.image_url, src.image_thumbnail_url, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts.success = true;
        result.data.concepts.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.concepts.recordcount# staging concepts records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // concept ancestors
    if (activeTables.listFind("conceptsancestors")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.concepts_ancestors dest
    USING #getSchema()#.stage$concepts_ancestors src
    ON (dest.concept_id = src.concept_id and dest.ancestor_id = src.ancestor_id)
    WHEN NOT MATCHED THEN
        INSERT (concept_id, ancestor_id,snapshotdate, snapshotfilenumber)
        VALUES (src.concept_id, src.ancestor_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts_ancestors.success = true;
        result.data.concepts_ancestors.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.concepts_ancestors.recordcount# staging concepts_ancestors records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // concepts counts
    if (activeTables.listFind("conceptscountsbyyear")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.concepts_counts_by_year dest
    USING #getSchema()#.stage$concepts_counts_by_year src
    ON (dest.concept_id = src.concept_id AND dest.year = src.year)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.works_count = src.works_count,
            dest.cited_by_count = src.cited_by_count,
            dest.oa_works_count = src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (concept_id, year, snapshotdate, snapshotfilenumber, works_count, cited_by_count, oa_works_count)
        VALUES (src.concept_id, src.year, src.snapshotdate, src.snapshotfilenumber, src.works_count, src.cited_by_count, src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts_counts_by_year.success = true;
        result.data.concepts_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.concepts_counts_by_year.recordcount# staging concepts_counts_by_year records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // concept ids
    if (activeTables.listFind("conceptsids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.concepts_ids dest
    USING #getSchema()#.stage$concepts_ids src
    ON (dest.concept_id = src.concept_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.openalex = src.openalex,
            dest.wikidata = src.wikidata,
            dest.wikipedia = src.wikipedia,
            dest.umls_aui = src.umls_aui,
            dest.umls_cui = src.umls_cui,
            dest.mag = src.mag
    WHEN NOT MATCHED THEN
        INSERT (concept_id, snapshotdate, snapshotfilenumber, openalex, wikidata, wikipedia, umls_aui, umls_cui, mag)
        VALUES (src.concept_id, src.snapshotdate, src.snapshotfilenumber, src.openalex, src.wikidata, src.wikipedia, src.umls_aui, src.umls_cui, src.mag)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts_ids.success = true;
        result.data.concepts_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.concepts_ids.recordcount# staging concepts_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // concepts related
    if (activeTables.listFind("conceptsrelatedconcepts")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.concepts_related_concepts dest
    USING #getSchema()#.stage$concepts_related_concepts src
    ON (dest.concept_id = src.concept_id AND dest.related_concept_id = src.related_concept_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.score = src.score
    WHEN NOT MATCHED THEN
        INSERT (concept_id, related_concept_id, snapshotdate, snapshotfilenumber, score)
        VALUES (src.concept_id, src.related_concept_id, src.snapshotdate, src.snapshotfilenumber, src.score)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts_related_concepts.success = true;
        result.data.concepts_related_concepts.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.concepts_related_concepts.recordcount# staging concepts_related_concepts records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeDomainsStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        domains: {success: false, recordcount: 0},
        domains_fields: {success: false, recordcount: 0},
        domains_ids: {success: false, recordcount: 0},
        domains_siblings: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("domains");

    // domains
    if (activeTables.listFind("domains")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.domains dest
    USING #getSchema()#.stage$domains src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.display_name = src.display_name,
          dest.display_name_alternatives = src.display_name_alternatives,
          dest.description = src.description,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.works_api_url=src.works_api_url,
          dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, display_name, display_name_alternatives, description, 
        works_count, cited_by_count, works_api_url, updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.display_name, src.display_name_alternatives, src.description, 
        src.works_count, src.cited_by_count, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.domains.success = true;
        result.data.domains.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.domains.recordcount# staging domains records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // ids
    if (activeTables.listFind("domainsids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.domains_ids dest
    USING #getSchema()#.stage$domains_ids src
    ON (dest.domain_id = src.domain_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.wikidata=src.wikidata,
          dest.wikipedia=src.wikipedia
    WHEN NOT MATCHED THEN
        INSERT (domain_id, snapshotdate, snapshotfilenumber, wikidata, wikipedia)
        VALUES (src.domain_id, src.snapshotdate, src.snapshotfilenumber, src.wikidata, src.wikipedia)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.domains_ids.success = true;
        result.data.domains_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.domains_ids.recordcount# staging domains_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // siblings
    if (activeTables.listFind("domainssiblings")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.domains_siblings dest
    USING #getSchema()#.stage$domains_siblings src
    ON (dest.domain_id = src.domain_id AND dest.sibling_id = src.sibling_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber
    WHEN NOT MATCHED THEN
        INSERT (domain_id, sibling_id, snapshotdate, snapshotfilenumber)
        VALUES (src.domain_id, src.sibling_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.domains_siblings.success = true;
        result.data.domains_siblings.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.domains_siblings.recordcount# staging domains_siblings records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // domains fields
    if (activeTables.listFind("domainsfields")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.domains_fields dest
    USING #getSchema()#.stage$domains_fields src
    ON (dest.domain_id = src.domain_id AND dest.field_id = src.field_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber
    WHEN NOT MATCHED THEN
        INSERT (domain_id, field_id, snapshotdate, snapshotfilenumber)
        VALUES (src.domain_id, src.field_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.domains_fields.success = true;
        result.data.domains_fields.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.domains_fields.recordcount# staging domains_fields records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeFieldsStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        fields: {success: false, recordcount: 0},
        fields_ids: {success: false, recordcount: 0},
        fields_siblings: {success: false, recordcount: 0},
        fields_subfields: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("fields");

    // fields
    if (activeTables.listFind("fields")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.fields dest
    USING #getSchema()#.stage$fields src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.display_name = src.display_name,
          dest.display_name_alternatives = src.display_name_alternatives,
          dest.description = src.description,
          dest.domain_id = src.domain_id,
          dest.works_count=src.works_count,
          dest.cited_by_count=src.cited_by_count,
          dest.works_api_url=src.works_api_url,
          dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, display_name, display_name_alternatives, description, domain_id, 
        works_count, cited_by_count, works_api_url, updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.display_name, src.display_name_alternatives, src.description, 
        src.domain_id, src.works_count, src.cited_by_count, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.fields.success = true;
        result.data.fields.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.fields.recordcount# staging fields records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // ids
    if (activeTables.listFind("fieldsids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.fields_ids dest
    USING #getSchema()#.stage$fields_ids src
    ON (dest.field_id = src.field_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber,
          dest.wikidata=src.wikidata,
          dest.wikipedia=src.wikipedia
    WHEN NOT MATCHED THEN
        INSERT (field_id, snapshotdate, snapshotfilenumber, wikidata, wikipedia)
        VALUES (src.field_id, src.snapshotdate, src.snapshotfilenumber, src.wikidata, src.wikipedia)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.fields_ids.success = true;
        result.data.fields_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.fields_ids.recordcount# staging fields_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // siblings
    if (activeTables.listFind("fieldssiblings")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.fields_siblings dest
    USING #getSchema()#.stage$fields_siblings src
    ON (dest.field_id = src.field_id AND dest.sibling_id = src.sibling_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber
    WHEN NOT MATCHED THEN
        INSERT (field_id, sibling_id, snapshotdate, snapshotfilenumber)
        VALUES (src.field_id, src.sibling_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.fields_siblings.success = true;
        result.data.fields_siblings.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.fields_siblings.recordcount# staging fields_siblings records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // fields subfields
    if (activeTables.listFind("fieldssubfields")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.fields_subfields dest
    USING #getSchema()#.stage$fields_subfields src
    ON (dest.field_id = src.field_id AND dest.subfield_id = src.subfield_id)
    WHEN MATCHED THEN
        UPDATE SET
          dest.snapshotdate = src.snapshotdate,
          dest.snapshotfilenumber = src.snapshotfilenumber
    WHEN NOT MATCHED THEN
        INSERT (field_id, subfield_id, snapshotdate, snapshotfilenumber)
        VALUES (src.field_id, src.subfield_id, src.snapshotdate, src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.fields_subfields.success = true;
        result.data.fields_subfields.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.fields_subfields.recordcount# staging fields_subfields records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeFundersStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        funders: {success: false, recordcount: 0},
        funders_counts_by_year: {success: false, recordcount: 0},
        funders_ids: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("funders");

    // funders
    if (activeTables.listFind("funders")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.funders dest
    USING #getSchema()#.stage$funders src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.display_name = src.display_name,
            dest.alternate_titles = src.alternate_titles,
            dest.country_code = src.country_code,
            dest.description = src.description,
            dest.homepage_url = src.homepage_url,
            dest.image_url = src.image_url,
            dest.image_thumbnail_url = src.image_thumbnail_url,
            dest.grants_count=src.grants_count,
            dest.works_count=src.works_count,
            dest.cited_by_count=src.cited_by_count,
            dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate, snapshotfilenumber, display_name, alternate_titles, country_code, description, homepage_url, image_url,
          image_thumbnail_url,grants_count, works_count, cited_by_count, updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.display_name, src.alternate_titles, src.country_code, src.description, src.homepage_url, src.image_url,
          src.image_thumbnail_url, src.grants_count, src.works_count, src.cited_by_count, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.funders.success = true;
        result.data.funders.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.funders.recordcount# staging funders records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // funders counts
    if (activeTables.listFind("funderscountsbyyear")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.funders_counts_by_year dest
    USING #getSchema()#.stage$funders_counts_by_year src
    ON (dest.funder_id = src.funder_id AND dest.year = src.year)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.works_count = src.works_count,
            dest.cited_by_count = src.cited_by_count
    WHEN NOT MATCHED THEN
        INSERT (funder_id, year, snapshotdate, snapshotfilenumber, works_count, cited_by_count)
        VALUES (src.funder_id, src.year, src.snapshotdate, src.snapshotfilenumber, src.works_count, src.cited_by_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.funders_counts_by_year.success = true;
        result.data.funders_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.funders_counts_by_year.recordcount# staging funders_counts_by_year records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // funders ids
    if (activeTables.listFind("fundersids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.funders_ids dest
    USING #getSchema()#.stage$funders_ids src
    ON (dest.funder_id = src.funder_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.openalex = src.openalex,
            dest.ror = src.ror,
            dest.wikidata = src.wikidata,
            dest.crossref = src.crossref,
            dest.doi = src.doi
    WHEN NOT MATCHED THEN
        INSERT (funder_id, snapshotdate, snapshotfilenumber, openalex, ror, wikidata, crossref, doi)
        VALUES (src.funder_id, src.snapshotdate, src.snapshotfilenumber, src.openalex, src.ror, src.wikidata, src.crossref, src.doi)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.funders_ids.success = true;
        result.data.funders_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.funders_ids.recordcount# staging funders_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function mergeAuthorsStageWithMain(parallel = 1){
    var result = {
      success: true,
      data: {
        authors: {success: false, recordcount: 0},
        authorsaffiliations: {success: false, recordcount: 0},
        authorslastinstitutions: {success: false, recordcount: 0},
        authors_counts_by_year: {success: false, recordcount: 0},
        authors_ids: {success: false, recordcount: 0},
        authorsconcepts: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("authors");

    // authors
    if (activeTables.listFind("authors")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.authors dest
    USING #getSchema()#.stage$authors src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.orcid = src.orcid,
            dest.display_name = src.display_name,
            dest.display_name_alternatives=src.display_name_alternatives,
            dest.works_count=src.works_count,
            dest.cited_by_count=src.cited_by_count,
            dest.last_known_institution=src.last_known_institution,
            dest.works_api_url=src.works_api_url,
            dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, snapshotdate,snapshotfilenumber, orcid, display_name, display_name_alternatives,works_count,cited_by_count,
          last_known_institution,works_api_url,updated_date)
        VALUES (src.id, src.snapshotdate, src.snapshotfilenumber, src.orcid, src.display_name, src.display_name_alternatives,src.works_count,src.cited_by_count,
          src.last_known_institution,src.works_api_url,src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authors.success = true;
        result.data.authors.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.authors.recordcount# staging authors records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // authors affiliations
    if (activeTables.listFind("authorsaffiliations")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.authors_affiliations dest
    USING #getSchema()#.stage$authors_affiliations src
    ON (dest.author_id = src.author_id AND dest.institution_id = src.institution_id and dest.year = src.year)   
    WHEN NOT MATCHED THEN
        INSERT (author_id, institution_id, year,snapshotdate,snapshotfilenumber)
        VALUES (src.author_id, src.institution_id, src.year,src.snapshotdate,src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authorsaffiliations.success = true;
        result.data.authorsaffiliations.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.authorsaffiliations.recordcount# staging authorsaffiliations records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // authors last known institutions
    if (activeTables.listFind("authorslastinstitutions")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.AUTHORS_LASTINSTITUTIONS dest
    USING #getSchema()#.stage$AUTHORS_LASTINSTITUTIONS src
    ON (dest.author_id = src.author_id AND dest.institution_id = src.institution_id)   
    WHEN NOT MATCHED THEN
        INSERT (author_id, institution_id,snapshotdate,snapshotfilenumber)
        VALUES (src.author_id, src.institution_id,src.snapshotdate,src.snapshotfilenumber)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authorslastinstitutions.success = true;
        result.data.authorslastinstitutions.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.authorslastinstitutions.recordcount# staging authorslastinstitutions records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // authors_counts_by_year
    if (activeTables.listFind("authorscountsbyyear")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.authors_counts_by_year dest
    USING #getSchema()#.stage$authors_counts_by_year src
    ON (dest.author_id = src.author_id and dest.year = src.year)
    WHEN MATCHED THEN
        UPDATE SET
            dest.works_count=src.works_count,
            dest.cited_by_count=src.cited_by_count,
            dest.oa_works_count=src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (author_id,year,snapshotdate,snapshotfilenumber,works_count,cited_by_count,oa_works_count)
        VALUES (src.author_id,src.year,src.snapshotdate,src.snapshotfilenumber,src.works_count,src.cited_by_count,src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authors_counts_by_year.success = true;
        result.data.authors_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.authors_counts_by_year.recordcount# staging authors_counts_by_year records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // authors_ids
    if (activeTables.listFind("authorsids")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.authors_ids dest
    USING #getSchema()#.stage$authors_ids src
    ON (dest.author_id = src.author_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.openalex=src.openalex,
            dest.orcid=src.orcid,
            dest.scopus=src.scopus,
            dest.twitter=src.twitter,
            dest.wikipedia=src.wikipedia,
            dest.mag=src.mag
    WHEN NOT MATCHED THEN
        INSERT (author_id,snapshotdate,snapshotfilenumber,openalex,orcid,scopus,twitter,wikipedia,mag)
        VALUES (src.author_id,src.snapshotdate,src.snapshotfilenumber,src.openalex,src.orcid,src.scopus,src.twitter,src.wikipedia,src.mag)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authors_ids.success = true;
        result.data.authors_ids.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.authors_ids.recordcount# staging authors_ids records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    // authors concepts
    if (activeTables.listFind("authorsconcepts")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.authors_concepts dest
    USING #getSchema()#.stage$authors_concepts src
    ON (dest.author_id = src.author_id AND dest.concept_id = src.concept_id)   
    WHEN MATCHED THEN
        UPDATE SET
            dest.snapshotdate = src.snapshotdate,
            dest.snapshotfilenumber = src.snapshotfilenumber,
            dest.score=src.score           
    WHEN NOT MATCHED THEN
        INSERT (author_id,concept_id,snapshotdate,snapshotfilenumber,score)
        VALUES (src.author_id,src.concept_id,src.snapshotdate,src.snapshotfilenumber,src.score)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authorsconcepts.success = true;
        result.data.authorsconcepts.recordcount = qryresult.recordcount;
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Sucessfully merged #result.data.authorsconcepts.recordcount# staging authorsaffiliations records with main");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  private any function clearEntityLogImport(required entity){
    var result = {success: false};
    queryExecute(
      "delete from #getSchema()#.entitylatestsync where entity =:entity",
      {entity: {value: arguments.entity, cfsqltype: "varchar"}},
      {datasource: getDatasource(), result: "qryresult"}
    );

    if (isStruct(qryResult)){
      result.success = true;
      outputSuccess("Cleared sync log results for entity #arguments.entity# from database");
    }

    return result;
  }

  private any function logEntityImport(
    required entity,
    required updatedate,
    required filenumber,
    required filename,
    required fileurl,
    required totalfiles,
    required recordcount,
    required manifesthash
  ){
    var result = {success: false};

    queryExecute(
      "MERGE INTO #getSchema()#.entitylatestsync dest
    USING (
      select '#arguments.entity#' as entity from dual) src
    ON (dest.entity = src.entity)
    WHEN MATCHED THEN
        UPDATE SET
            dest.updatedate = :updatedate,
            dest.filenumber = :filenumber,
            dest.filename=:filename,
            dest.fileurl=:fileurl,
            dest.totalfiles=:totalfiles,
            dest.recordcount=:recordcount,
            dest.manifesthash=:manifesthash,
            dest.createdat=current_timestamp
    WHEN NOT MATCHED THEN
        INSERT (entity, updatedate,filenumber,filename,fileurl,totalfiles,recordcount,manifesthash)
        VALUES (:entity,:updatedate,:filenumber,:filename,:fileurl,:totalfiles,:recordcount,:manifesthash)
    ",
      {
        entity: {value: arguments.entity, cfsqltype: "varchar"},
        updatedate: {value: createODBCDate(arguments.updatedate), cfsqltype: "date"},
        filenumber: {value: arguments.filenumber, cfsqltype: "numeric"},
        filename: {value: arguments.filename, cfsqltype: "varchar"},
        fileurl: {value: arguments.fileurl, cfsqltype: "varchar"},
        totalfiles: {value: arguments.totalfiles, cfsqltype: "numeric"},
        recordcount: {value: arguments.recordcount, cfsqltype: "numeric"},
        manifesthash: {value: arguments.manifesthash, cfsqltype: "varchar"}
      },
      {datasource: getDatasource(), result: "qryresult"}
    );

    if (isStruct(qryResult)){
      result.success = true;
      outputSuccess("Logged sync results to database");
    }
    return result;
  }

}
