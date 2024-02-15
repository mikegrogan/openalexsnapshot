component accessors="true" extends="helper" {

  // property name="schema";
  property name="csvDelimiter";
  property name="charset";
  property name="writeFlushLimit";

  function init(){
    this.csvDelimiter = chr(9); // tab
    this.setwriteFlushLimit(500);
    this.charset = createObject("java", "java.nio.charset.Charset").forName("UTF-8");
    this.s3 = new lib.s3();
    this.tables = new tableSchema();
    this.merge = new lib.merge();

    return this;
  }

  public any function handleEntities(entityList){
    for (var entity in arguments.entityList){
      outputH1("<div id=""#entity#"">Syncing #entity#</div>");
      flush;

      outputH2("Working on #entity# Inserts/Updates");
      var manifestResult = this.s3.downloadEntityManifestFromOA(entity = entity);
      var processEntityResult = processEntitySnapshots(entity = entity);

      if (processEntityResult.success) {
        outputH2("Working on #entity# Deletions");
        var processMergeResult = this.merge.processEntityMergedIds(entity = entity);        
      }
    }

    return true;
  }

  /**
   * Loops through entity snapshots and loads them into the database
   *
   * @entity
   * @snapshotLimit set to numeric value if you want to limit the number of snapshot imports. Mostly for debugging purposes
   */
  private any function processEntitySnapshots(required entity, snapshotLimit =1){
    var result = {success: false};

    var filesToProcess = getEntityFilesNotComplete(entity = arguments.entity);

    if (filesToProcess.success){
      var limit = 0;

      if (filesToProcess.data.len() > 0){
        outputH2("Processing remaining #arguments.entity# snapshots");
        if (arguments.keyExists("snapshotlimit")){
          outputNormal("Limiting snapshot processing to #arguments.snapshotLimit#");
        }
      }
      else{
        outputH2("All up to date with #arguments.entity# snapshots");
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

        var compressedFilePath = application.localpath & "compressed\#snapshot.updateDate#\#snapshot.filename#";
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
          var uncompressedPath = application.localpath & "uncompressed\#snapshot.updateDate#\";

          if (!directoryExists(uncompressedPath)){
            directoryCreate(uncompressedPath);
          }

          var unCompressedFile = gunzipFile(compressedFilePath, uncompressedPath);

          if (unCompressedFile.success){
            deleteFile(compressedFilePath, true);

            var processed = processEntityData(entity = arguments.entity, snapshotfile = unCompressedFile);
            if (processed.success){
              var imported = importDataToStaging(entity = arguments.entity);
              if (!imported){
                outputError("There was an error during the database import. Script has been halted. Please review the \files\loader\#arguments.entity#\logs folder for more details");
              }
              else{
                var merged = mergeEntityStageWithProduction(entity = arguments.entity);
                if (merged.success){
                  deleteFile(unCompressedFile.filepath, true);

                  outputh3("Cleaning up #arguments.entity# staging tables/files");

                  // clear entity staging tables
                  var clear = this.tables.clearStagingTables(entity = arguments.entity);

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
                      recordcount = snapshot.meta.record_count
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


  public any function importDataToStaging(entity){
    var result = true;
    var importlist = this.tables.getActiveTableNamesList(arguments.entity);

    outputH3("Starting #arguments.entity# csv import into the staging tables");
    flush;

    cfexecute(
      name = "C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe",
      arguments = "-File #application.localpath#loader\#arguments.entity#\run.ps1 -oraclepath #application.localpath#loader\#arguments.entity# -environment #application.environment# -importlist ""#importlist#"" 2>&1",
      variable = "runoutput",
      errorVariable = "err",
      timeout = "1000"
    );

    if (variables.err !== ""){
      result = false;
      outputError(err);
    }
    else{
      if (runoutput.findNoCase("[Error]")) {
        result = false;
        outputError(runoutput.reReplaceNoCase("SQL\*Loader", "<br><br>SQL*Loader", "all"));
      }
      else{
        outputSuccess("Sucessfully imported #arguments.entity# staging data");
        // breaking up the output
        outputSuccess(runoutput.reReplaceNoCase("SQL\*Loader", "<br><br>SQL*Loader", "all"));
      }
      flush;
    }

    return result;
  }

  /**
   * Helper function to route processing of entity data
   *
   * @entity
   * @snapshotfile uncompressed data file to process
   */
  private any function processEntityData(entity, snapshotfile){
    var result = {success: false};

    outputH3("Creating the csv files for import into Oracle");
    outputNormal("Using #this.getwriteFlushLimit()# as the number of records to save in memory before flushing to the file");
    flush;

    switch (arguments.entity){
      case "authors":
        result = processAuthorsData(arguments.snapshotfile);
        break;
      case "concepts":
        result = processConceptsData(arguments.snapshotfile);
        break;
      case "funders":
        result = processFundersData(arguments.snapshotfile);
        break;
      case "institutions":
        result = processInstitutionsData(arguments.snapshotfile);
        break;
      case "publishers":
        result = processPublishersData(arguments.snapshotfile);
        break;
      case "sources":
        result = processSourcesData(arguments.snapshotfile);
        break;
      case "works":
        result = processWorksData(arguments.snapshotfile);
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

    var latest = getLatestEntityFileSynced(entity = arguments.entity);

    if (latest.recordcount == 1){
      compareDate = latest.updateDate;
      compareFileNumber = latest.filenumber;
      outputNormal("Latest synced #arguments.entity# snapshot found is #dateFormat(compareDate, "yyyy-mm-dd")# &##10142; #latest.filename#");
    }

    result.data = result.data.filter((row) => {
      var dateComparison = dateCompare(row.updateDate, compareDate, "d");

      return dateComparison == 1 || (dateComparison == 0 ? row.filenumber > compareFileNumber : false);
    });

    return result;
  }

  private any function getManifestFile(entity){
    var result = {success: false, data: []};

    var manifestPath = application.localpath & "manifest/#arguments.entity#.json";
    if (fileExists(manifestPath)){
      var fileData = fileRead(manifestPath);
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
      result.csv[simplifiedName] = application.localpath & "loader\#arguments.entity#\csv\#simplifiedName#.csv";

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

  private any function processWorksData(snapshotfile){
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
            inputs.data.works.append(line.doi);
            inputs.data.works.append(line.title.reReplaceNoCase("[\n\r]", " ", "all"));
            inputs.data.works.append(line.display_name.reReplaceNoCase("[\n\r]", " ", "all"));
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
          // for (var authorship in line.authorships){
          //   if (!authorship.keyExists("institutions") || authorship.keyExists("institutions") && authorship.institutions.isEmpty()){
          //     authorship.institutions = [{id: ""}];
          //   }
          //   if (!authorship.keyExists("raw_affiliation_string")){
          //     authorship.raw_affiliation_string = "";
          //   }

          //   worksAuthorshipsArr.append(line.id);
          //   worksAuthorshipsArr.append(authorship.author_position);
          //   worksAuthorshipsArr.append(authorship.author.id);
          //   worksAuthorshipsArr.append(authorship.institutions[1].id);
          //   worksAuthorshipsArr.append(authorship.raw_affiliation_string.reReplaceNoCase("[\n\r]", " ", "all"));
          //   worksAuthorshipsWriter.write(worksAuthorshipsArr.toList(this.csvDelimiter));
          //   worksAuthorshipsWriter.newLine();
          //   worksAuthorshipsArr.clear();
          // }

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

              inputs.data.worksbestoalocations.append(line.id);
              inputs.data.worksbestoalocations.append(line.best_oa_location.source.id);
              inputs.data.worksbestoalocations.append(line.best_oa_location.landing_page_url);
              inputs.data.worksbestoalocations.append(line.best_oa_location.pdf_url);
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
                inputs.data.worksbiblio.append(line.biblio.volume);
                inputs.data.worksbiblio.append(line.biblio.issue);
                inputs.data.worksbiblio.append(line.biblio.first_page);
                inputs.data.worksbiblio.append(line.biblio.last_page);
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
          // for (var location in line.locations){
          //   if (!location.keyExists("source")){
          //     location.source.id = "";
          //   }
          //   if (!location.keyExists("landing_page_url")){
          //     location.landing_page_url = "";
          //   }
          //   if (!location.keyExists("pdf_url")){
          //     location.pdf_url = "";
          //   }
          //   if (!location.keyExists("version")){
          //     location.version = "";
          //   }
          //   if (!location.keyExists("license")){
          //     location.license = "";
          //   }

          //   locationsArr.append(line.id);
          //   locationsArr.append(location.source.id);
          //   locationsArr.append(location.landing_page_url);
          //   locationsArr.append(location.pdf_url);
          //   (location.is_oa) ? locationsArr.append("1") : locationsArr.append("0");
          //   locationsArr.append(location.version);
          //   locationsArr.append(location.license);

          //   worksLocationsWriter.write(locationsArr.toList(this.csvDelimiter));
          //   worksLocationsWriter.newLine();
          //   locationsArr.clear();
          // }

          // mesh
          if (inputs.data.keyExists("worksmesh")){
            for (var mesh in line.mesh){
              if (!mesh.keyExists("qualifier_name")){
                mesh.qualifier_name = "";
              }

              inputs.data.worksmesh.append(mesh.descriptor_ui & mesh.qualifier_ui);
              inputs.data.worksmesh.append(line.id);
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
              (line.open_access.is_oa) ? inputs.data.worksopenaccess.append("1") : inputs.data.worksopenaccess.append("0");
              inputs.data.worksopenaccess.append(line.open_access.oa_status);
              inputs.data.worksopenaccess.append(line.open_access.oa_url);
              (line.open_access.any_repository_has_fulltext) ? inputs.data.worksopenaccess.append("1") : inputs.data.worksopenaccess.append("0");
              inputs.writer.worksopenaccess.write(inputs.data.worksopenaccess.toList(this.csvDelimiter));
              inputs.writer.worksopenaccess.newLine();
              inputs.data.worksopenaccess.clear();
            }
          }

          // primary

          // referenced
          if (inputs.data.keyExists("worksreferencedworks")){
            for (var referenced_work_id in line.referenced_works){
              inputs.data.worksReferencedWorks.append(line.id);
              inputs.data.worksReferencedWorks.append(referenced_work_id);
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
              inputs.writer.worksRelatedWorks.write(inputs.data.worksRelatedWorks.toList(this.csvDelimiter));
              inputs.writer.worksRelatedWorks.newLine();
              inputs.data.worksRelatedWorks.clear();
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

  private any function processSourcesData(snapshotfile){
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
            inputs.data.sources.append(line.issn_l);
            (line.issn.isEmpty()) ? inputs.data.sources.append("") : inputs.data.sources.append(line.issn.toJson());
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
            inputs.data.sourcesids.append(line.ids.openalex);
            inputs.data.sourcesids.append(line.ids.issn_l);
            (line.issn.isEmpty()) ? inputs.data.sourcesids.append("") : inputs.data.sourcesids.append(line.issn.toJson());
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

  private any function processPublishersData(snapshotfile){
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
            inputs.data.publishers.append(line.display_name);
            (line.alternate_titles.isEmpty()) ? inputs.data.publishers.append("") : inputs.data.publishers.append(
              line.alternate_titles.toJson()
            );
            (line.country_codes.isEmpty()) ? inputs.data.publishers.append("") : inputs.data.publishers.append(
              line.country_codes.toJson()
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

  private any function processInstitutionsData(snapshotfile){
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
            inputs.data.institutions.append(line.ror);
            inputs.data.institutions.append(line.display_name);
            inputs.data.institutions.append(line.country_code);
            inputs.data.institutions.append(line.type);
            inputs.data.institutions.append(line.homepage_url);
            inputs.data.institutions.append(line.image_url);
            inputs.data.institutions.append(line.image_thumbnail_url);
            (line.display_name_acronyms.isEmpty()) ? inputs.data.institutions.append("") : inputs.data.institutions.append(
              line.display_name_acronyms.toJson()
            );
            (line.display_name_alternatives.isEmpty()) ? inputs.data.institutions.append("") : inputs.data.institutions.append(
              line.display_name_alternatives.toJson()
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

  private any function processFundersData(snapshotfile){
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
            inputs.data.funders.append(line.display_name);
            (line.alternate_titles.isEmpty()) ? inputs.data.funders.append("") : inputs.data.funders.append(
              line.alternate_titles.toJson()
            );
            inputs.data.funders.append(line.country_code);
            inputs.data.funders.append(line.description);
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
              inputs.data.funderscountsbyyear.append(counts.works_count);
              inputs.data.funderscountsbyyear.append(counts.cited_by_count);

              inputs.writer.funderscountsbyyear.write(inputs.data.funderscountsbyyear.toList(this.csvDelimiter));
              inputs.writer.funderscountsbyyear.newLine();
              inputs.data.funderscountsbyyear.clear();
            }
          }

          //Ids
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

  private any function processAuthorsData(snapshotfile){
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
            inputs.data.authors.append(line.orcid);
            inputs.data.authors.append(line.display_name);
            (line.display_name_alternatives.isEmpty()) ? inputs.data.authors.append("") : inputs.data.authors.append(
              line.display_name_alternatives.toJson()
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
            if (line.keyExists("line.affiliations")) {
              for (var affiliation in line.affiliations){              
                for (var year in affiliation.years){
                  inputs.data.authorsaffiliations.append(line.id);
                  inputs.data.authorsaffiliations.append(affiliation.institution.id);
                  inputs.data.authorsaffiliations.append(year);                
                  inputs.writer.authorsaffiliations.write(inputs.data.authorsaffiliations.toList(this.csvDelimiter));
                  inputs.writer.authorsaffiliations.newLine();
                  inputs.data.authorsaffiliations.clear();
                }
              }
            }
          }

          // AUTHORSCOUNTS
          if (inputs.data.keyExists("authorscountsbyyear")){
            for (var counts in line.counts_by_year){
              inputs.data.authorscountsbyyear.append(line.id);
              inputs.data.authorscountsbyyear.append(counts.year);
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

  private any function processConceptsData(snapshotfile){
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
            inputs.data.concepts.append(line.wikidata);
            inputs.data.concepts.append(line.display_name);
            inputs.data.concepts.append(line.level);
            inputs.data.concepts.append(line.description);
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
            inputs.data.conceptsids.append(line.ids.openalex);
            inputs.data.conceptsids.append(line.ids.wikidata);
            inputs.data.conceptsids.append(line.ids.wikipedia);
            (line.ids.umls_aui.isEmpty()) ? inputs.data.conceptsids.append("") : inputs.data.conceptsids.append(
              line.ids.umls_aui.toJson()
            );
            (line.ids.umls_cui.isEmpty()) ? inputs.data.conceptsids.append("") : inputs.data.conceptsids.append(
              line.ids.umls_cui.toJson()
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
  private any function mergeEntityStageWithProduction(entity){
    var result = {success: false};

    var parallel = 10;

    outputh3("Merge #arguments.entity# staging tables with their main tables");
    flush;

    switch (arguments.entity){
      case "authors":
        result = mergeAuthorsStageWithProduction(parallel);
        break;
      case "concepts":
        result = mergeConceptsStageWithProduction(parallel);
        break;
      case "funders":
        result = mergeFundersStageWithProduction(parallel);
        break;
      case "institutions":
        result = mergeInstitutionsStageWithProduction(parallel);
        break;
      case "publishers":
        result = mergePublishersStageWithProduction(parallel);
        break;
      case "sources":
        result = mergeSourcesStageWithProduction(parallel);
        break;
      case "works":
        result = mergeWorksStageWithProduction(parallel);
        break;
      default:
    }

    return result;
  }

  private any function mergeWorksStageWithProduction(parallel = 1){
    var result = {
      success: true,
      data: {
        works: {success: false, recordcount: 0},
        works_authorships: {success: false, recordcount: 0},
        works_best_oa_locations: {success: false, recordcount: 0},
        works_biblio: {success: false, recordcount: 0},
        works_concepts: {success: false, recordcount: 0},
        works_ids: {success: false, recordcount: 0},
        works_location: {success: false, recordcount: 0},
        works_mesh: {success: false, recordcount: 0},
        works_open_access: {success: false, recordcount: 0},
        works_primary_locations: {success: false, recordcount: 0},
        works_referenced_works: {success: false, recordcount: 0},
        works_related_works: {success: false, recordcount: 0}
      }
    };

    var activeTables = this.tables.getActiveTableNamesList("sources");

    // works
    if (activeTables.listFind("works")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works dest
    USING #getSchema()#.stage$works src
    ON (dest.id = src.id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.doi = src.doi,
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
        INSERT (id, doi, title, display_name, publication_year, publication_date, type, cited_by_count, is_retracted, is_paratext,
          cited_by_api_url, language)
        VALUES (src.id, src.doi, src.title, src.display_name, src.publication_year, src.publication_date, src.type, src.cited_by_count, 
          src.is_retracted, src.is_paratext, src.cited_by_api_url, src.language)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works.success = true;
        result.data.works.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works.recordcount# staging works records with production");
      }
      else{
        result.success = false;
      }
    }

    // authorships
    // queryExecute(
    //   "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_authorships dest
    // USING #getSchema()#.stage$works_authorships src
    // ON (dest.work_id = src.work_id AND dest.author_id = src.author_id)
    // WHEN MATCHED THEN
    //     UPDATE SET
    //         dest.author_position = src.author_position,
    //         dest.raw_affiliation_string = src.raw_affiliation_string
    // WHEN NOT MATCHED THEN
    //     INSERT /*+ IGNORE_DUP_KEY */ (work_id, author_position, author_id, institution_id, raw_affiliation_string)
    //     VALUES (src.work_id, src.author_position, src.author_id, src.institution_id, src.raw_affiliation_string)",
    //   {},
    //   {datasource: getDatasource(), result: "qryresult"}
    // );
    // if (isStruct(qryresult)){
    //   result.data.works_authorships.success = true;
    //   result.data.works_authorships.recordcount = qryresult.recordcount;
    // }
    // else{
    //   result.success = false;
    // }

    // works_best_oa_locations
    if (activeTables.listFind("worksbestoalocations")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_best_oa_locations dest
    USING #getSchema()#.stage$works_best_oa_locations src
    ON (dest.work_id = src.work_id AND dest.source_id = src.source_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.landing_page_url = src.landing_page_url,
            dest.pdf_url = src.pdf_url,
            dest.is_oa = src.is_oa,
            dest.version = src.version,
            dest.license = src.license
    WHEN NOT MATCHED THEN
        INSERT (work_id, source_id, landing_page_url, pdf_url, is_oa, version, license)
        VALUES (src.work_id, src.source_id, src.landing_page_url, src.pdf_url, src.is_oa, src.version, src.license)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_best_oa_locations.success = true;
        result.data.works_best_oa_locations.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works_best_oa_locations.recordcount# staging works_best_oa_locations records with production");
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
            dest.volume = src.volume,
            dest.issue = src.issue,
            dest.first_page = src.first_page,
            dest.last_page = src.last_page
    WHEN NOT MATCHED THEN
        INSERT (work_id, volume, issue, first_page, last_page)
        VALUES (src.work_id, src.volume, src.issue, src.first_page, src.last_page)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_biblio.success = true;
        result.data.works_biblio.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works_biblio.recordcount# staging works_biblio records with production");
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
        INSERT (work_id, concept_id, score)
        VALUES (src.work_id, src.concept_id, src.score)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_concepts.success = true;
        result.data.works_concepts.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works_concepts.recordcount# staging works_concepts records with production");
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
            dest.openalex = src.openalex,
            dest.doi = src.doi,
            dest.mag = src.mag,
            dest.pmid = src.pmid,
            dest.pmcid = src.pmcid
    WHEN NOT MATCHED THEN
        INSERT (work_id, openalex, doi, mag, pmid, pmcid)
        VALUES (src.work_id, src.openalex, src.doi, src.mag, src.pmid, src.pmcid)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_ids.success = true;
        result.data.works_ids.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works_ids.recordcount# staging works_ids records with production");
      }
      else{
        result.success = false;
      }
    }

    // locations
    // queryExecute(
    //   "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_locations dest
    // USING #getSchema()#.stage$works_locations src
    // ON (dest.work_id = src.work_id AND dest.source_id = src.source_id)
    // WHEN MATCHED THEN
    //     UPDATE SET
    //         dest.landing_page_url = src.landing_page_url,
    //         dest.pdf_url = src.pdf_url,
    //         dest.is_oa = src.is_oa,
    //         dest.version = src.version,
    //         dest.license = src.license
    // WHEN NOT MATCHED THEN
    //     INSERT (work_id, source_id, landing_page_url, pdf_url, is_oa, version, license)
    //     VALUES (src.work_id, src.source_id, src.landing_page_url, src.pdf_url, src.is_oa, src.version, src.license)",
    //   {},
    //   {datasource: getDatasource(), result: "qryresult"}
    // );
    // if (isStruct(qryresult)){
    //   result.data.works_locations.success = true;
    //   result.data.works_locations.recordcount = qryresult.recordcount;
    // outputSuccess("Sucessfully merged #result.data.works_location.recordcount# staging works_location records with production");
    // }
    // else{
    //   result.success = false;
    // }

    // mesh
    if (activeTables.listFind("worksmesh")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_mesh dest
    USING #getSchema()#.stage$works_mesh src
    ON (dest.work_id = src.work_id AND dest.merge_id = src.merge_id)
    WHEN MATCHED THEN
        UPDATE SET
            dest.descriptor_ui = src.descriptor_ui,
            dest.descriptor_name = src.descriptor_name,
            dest.qualifier_ui = src.qualifier_ui,
            dest.qualifier_name = src.qualifier_name,
            dest.is_major_topic = src.is_major_topic
    WHEN NOT MATCHED THEN
        INSERT (merge_id, work_id, descriptor_ui, descriptor_name, qualifier_ui, qualifier_name, is_major_topic)
        VALUES (src.merge_id, src.work_id, src.descriptor_ui, src.descriptor_name, src.qualifier_ui, src.qualifier_name, src.is_major_topic)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_mesh.success = true;
        result.data.works_mesh.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works_mesh.recordcount# staging works_mesh records with production");
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
            dest.is_oa = src.is_oa,
            dest.oa_status = src.oa_status,
            dest.oa_url = src.oa_url,
            dest.any_repository_has_fulltext = src.any_repository_has_fulltext
    WHEN NOT MATCHED THEN
        INSERT (work_id, is_oa, oa_status, oa_url, any_repository_has_fulltext)
        VALUES (src.work_id, src.is_oa, src.oa_status, src.oa_url, src.any_repository_has_fulltext)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_open_access.success = true;
        result.data.works_open_access.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works_open_access.recordcount# staging works_open_access records with production");
      }
      else{
        result.success = false;
      }
    }

    // primary

    // referenced
    if (activeTables.listFind("worksreferencedworks")){
      queryExecute(
        "MERGE /*+ PARALLEL(dest, #arguments.parallel#) */ INTO #getSchema()#.works_referenced_works dest
    USING #getSchema()#.stage$works_referenced_works src
    ON (dest.work_id = src.work_id AND dest.referenced_work_id = src.referenced_work_id)
    WHEN NOT MATCHED THEN
        INSERT (work_id, referenced_work_id)
        VALUES (src.work_id, src.referenced_work_id)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_referenced_works.success = true;
        result.data.works_referenced_works.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works_referenced_works.recordcount# staging works_referenced_works records with production");
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
        INSERT (work_id, related_work_id)
        VALUES (src.work_id, src.related_work_id)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.works_related_works.success = true;
        result.data.works_related_works.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.works_related_works.recordcount# staging works_related_works records with production");
      }
      else{
        result.success = false;
      }
    }

    // outputSuccess("Sucessfully merged #result.data.works_authorships.recordcount# staging works_authorships records with production");
    // outputSuccess("Sucessfully merged #result.data.works_primary_locations.recordcount# staging works_primary_locations records with production");

    flush;
    return result;
  }

  private any function mergeSourcesStageWithProduction(parallel = 1){
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
        INSERT (id, issn_l, issn, display_name, publisher, works_count, cited_by_count, is_oa, is_in_doaj,
          homepage_url, works_api_url, updated_date)
        VALUES (src.id, src.issn_l, src.issn, src.display_name, src.publisher, src.works_count, src.cited_by_count, src.is_oa, 
          src.is_in_doaj, src.homepage_url, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.sources.success = true;
        result.data.sources.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.sources.recordcount# staging sources records with production");
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
            dest.works_count=src.works_count,
            dest.cited_by_count=src.cited_by_count,
            dest.oa_works_count=src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (source_id, year, works_count, cited_by_count, oa_works_count)
        VALUES (src.source_id, src.year, src.works_count, src.cited_by_count, src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.sources_counts_by_year.success = true;
        result.data.sources_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.sources_counts_by_year.recordcount# staging sources_counts_by_year records with production");
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
        outputSuccess("Sucessfully merged #result.data.sources_ids.recordcount# staging sources_ids records with production");
      }
      else{
        result.success = false;
      }
    }

    flush;
    return result;
  }

  private any function mergePublishersStageWithProduction(parallel = 1){
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
        INSERT (id, display_name, alternate_titles, country_codes, hierarchy_level, parent_publisher, homepage_url,
        image_url,image_thumbnail_url,works_count, cited_by_count, sources_api_url, updated_date)
        VALUES (src.id, src.display_name, src.alternate_titles, src.country_codes, src.hierarchy_level, src.parent_publisher, 
        src.homepage_url,src.image_url,src.image_thumbnail_url,src.works_count, src.cited_by_count, src.sources_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.publishers.success = true;
        result.data.publishers.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.publishers.recordcount# staging publishers records with production");
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
            dest.works_count=src.works_count,
            dest.cited_by_count=src.cited_by_count,
            dest.oa_works_count=src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (publisher_id, year, works_count, cited_by_count, oa_works_count)
        VALUES (src.publisher_id, src.year, src.works_count, src.cited_by_count, src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.publishers_counts_by_year.success = true;
        result.data.publishers_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.publishers_counts_by_year.recordcount# staging publishers_counts_by_year records with production");
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
            dest.openalex=src.openalex,
            dest.ror=src.ror,
            dest.wikidata=src.wikidata
    WHEN NOT MATCHED THEN
        INSERT (publisher_id, openalex, ror, wikidata)
        VALUES (src.publisher_id, src.openalex, src.ror, src.wikidata)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.publishers_ids.success = true;
        result.data.publishers_ids.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.publishers_ids.recordcount# staging publishers_ids records with production");
      }
      else{
        result.success = false;
      }
    }

    flush;
    return result;
  }

  private any function mergeInstitutionsStageWithProduction(parallel = 1){
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
        INSERT (id, ror, display_name, country_code, type, homepage_url, image_url, image_thumbnail_url, 
        display_name_acronyms,display_name_alternatives, works_count, cited_by_count, works_api_url, updated_date)
        VALUES (src.id, src.ror, src.display_name, src.country_code, src.type, src.homepage_url, src.image_url, src.image_thumbnail_url, 
        src.display_name_acronyms, src.display_name_alternatives, src.works_count, src.cited_by_count, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions.success = true;
        result.data.institutions.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.institutions.recordcount# staging institutions records with production");
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
            dest.relationship = src.relationship            
    WHEN NOT MATCHED THEN
        INSERT (institution_id, associated_institution_id, relationship)
        VALUES (src.institution_id, src.associated_institution_id, src.relationship)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions_associated_institutions.success = true;
        result.data.institutions_associated_institutions.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.institutions_associated_institutions.recordcount# staging institutions_associated_institutions records with production");
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
            dest.works_count = src.works_count,
            dest.cited_by_count = src.cited_by_count,
            dest.oa_works_count = src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (institution_id, year, works_count, cited_by_count, oa_works_count)
        VALUES (src.institution_id, src.year, src.works_count, src.cited_by_count, src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions_counts_by_year.success = true;
        result.data.institutions_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.institutions_counts_by_year.recordcount# staging institutions_counts_by_year records with production");
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
            dest.city = src.city,
            dest.geonames_city_id = src.geonames_city_id,
            dest.region = src.region,
            dest.country_code = src.country_code,
            dest.country = src.country,
            dest.latitude = src.latitude,
            dest.longitude = src.longitude
    WHEN NOT MATCHED THEN
        INSERT (institution_id, city, geonames_city_id, region, country_code, country, latitude, longitude)
        VALUES (src.institution_id, src.city, src.geonames_city_id, src.region, src.country_code, src.country, src.latitude, src.longitude)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions_geo.success = true;
        result.data.institutions_geo.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.institutions_geo.recordcount# staging institutions_geo records with production");
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
            dest.openalex = src.openalex,
            dest.ror = src.ror,
            dest.grid = src.grid,
            dest.wikipedia = src.wikipedia,
            dest.wikidata = src.wikidata,
            dest.mag = src.mag
    WHEN NOT MATCHED THEN
        INSERT (institution_id, openalex, ror, grid, wikipedia, wikidata, mag)
        VALUES (src.institution_id, src.openalex, src.ror, src.grid, src.wikipedia, src.wikidata, src.mag)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.institutions_ids.success = true;
        result.data.institutions_ids.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.institutions_ids.recordcount# staging institutions_ids records with production");
      }
      else{
        result.success = false;
      }
    }

    flush;
    return result;
  }

  private any function mergeConceptsStageWithProduction(parallel = 1){
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
        INSERT (id, wikidata, display_name, concept_level, description, works_count, cited_by_count,
          image_url, image_thumbnail_url, works_api_url, updated_date)
        VALUES (src.id, src.wikidata, src.display_name, src.concept_level, src.description, src.works_count, src.cited_by_count,
        src.image_url, src.image_thumbnail_url, src.works_api_url, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts.success = true;
        result.data.concepts.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.concepts.recordcount# staging concepts records with production");
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
        INSERT (concept_id, ancestor_id)
        VALUES (src.concept_id, src.ancestor_id)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts_ancestors.success = true;
        result.data.concepts_ancestors.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.concepts_ancestors.recordcount# staging concepts_ancestors records with production");
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
            dest.works_count = src.works_count,
            dest.cited_by_count = src.cited_by_count,
            dest.oa_works_count = src.oa_works_count
    WHEN NOT MATCHED THEN
        INSERT (concept_id, year, works_count, cited_by_count, oa_works_count)
        VALUES (src.concept_id, src.year, src.works_count, src.cited_by_count, src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts_counts_by_year.success = true;
        result.data.concepts_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.concepts_counts_by_year.recordcount# staging concepts_counts_by_year records with production");
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
            dest.openalex = src.openalex,
            dest.wikidata = src.wikidata,
            dest.wikipedia = src.wikipedia,
            dest.umls_aui = src.umls_aui,
            dest.umls_cui = src.umls_cui,
            dest.mag = src.mag
    WHEN NOT MATCHED THEN
        INSERT (concept_id, openalex, wikidata, wikipedia, umls_aui, umls_cui, mag)
        VALUES (src.concept_id, src.openalex, src.wikidata, src.wikipedia, src.umls_aui, src.umls_cui, src.mag)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts_ids.success = true;
        result.data.concepts_ids.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.concepts_ids.recordcount# staging concepts_ids records with production");
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
            dest.score = src.score
    WHEN NOT MATCHED THEN
        INSERT (concept_id, related_concept_id, score)
        VALUES (src.concept_id, src.related_concept_id, src.score)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.concepts_related_concepts.success = true;
        result.data.concepts_related_concepts.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.concepts_related_concepts.recordcount# staging concepts_related_concepts records with production");
      }
      else{
        result.success = false;
      }
    }

    flush;
    return result;
  }

  private any function mergeFundersStageWithProduction(parallel = 1){
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
        INSERT (id, display_name, alternate_titles, country_code, description, homepage_url, image_url,
          image_thumbnail_url,grants_count, works_count, cited_by_count, updated_date)
        VALUES (src.id, src.display_name, src.alternate_titles, src.country_code, src.description, src.homepage_url, src.image_url,
          src.image_thumbnail_url, src.grants_count, src.works_count, src.cited_by_count, src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.funders.success = true;
        result.data.funders.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.funders.recordcount# staging funders records with production");
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
            dest.works_count = src.works_count,
            dest.cited_by_count = src.cited_by_count
    WHEN NOT MATCHED THEN
        INSERT (funder_id, year, works_count, cited_by_count)
        VALUES (src.funder_id, src.year, src.works_count, src.cited_by_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.funders_counts_by_year.success = true;
        result.data.funders_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.funders_counts_by_year.recordcount# staging funders_counts_by_year records with production");
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
            dest.openalex = src.openalex,
            dest.ror = src.ror,
            dest.wikidata = src.wikidata,
            dest.crossref = src.crossref,
            dest.doi = src.doi
    WHEN NOT MATCHED THEN
        INSERT (funder_id, openalex, ror, wikidata, crossref, doi)
        VALUES (src.funder_id, src.openalex, src.ror, src.wikidata, src.crossref, src.doi)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.funders_ids.success = true;
        result.data.funders_ids.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.funders_ids.recordcount# staging funders_ids records with production");
      }
      else{
        result.success = false;
      }
    }

    flush;
    return result;
  }

  private any function mergeAuthorsStageWithProduction(parallel = 1){
    var result = {
      success: true,
      data: {
        authors: {success: false, recordcount: 0},
        authorsaffiliations: {success: false, recordcount: 0},
        authors_counts_by_year: {success: false, recordcount: 0},
        authors_ids: {success: false, recordcount: 0}
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
            dest.orcid = src.orcid,
            dest.display_name = src.display_name,
            dest.display_name_alternatives=src.display_name_alternatives,
            dest.works_count=src.works_count,
            dest.cited_by_count=src.cited_by_count,
            dest.last_known_institution=src.last_known_institution,
            dest.works_api_url=src.works_api_url,
            dest.updated_date=src.updated_date
    WHEN NOT MATCHED THEN
        INSERT (id, orcid, display_name, display_name_alternatives,works_count,cited_by_count,
          last_known_institution,works_api_url,updated_date)
        VALUES (src.id, src.orcid, src.display_name, src.display_name_alternatives,src.works_count,src.cited_by_count,
          src.last_known_institution,src.works_api_url,src.updated_date)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authors.success = true;
        result.data.authors.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.authors.recordcount# staging authors records with production");
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
        INSERT (author_id, institution_id, year)
        VALUES (src.author_id, src.institution_id, src.year)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authorsaffiliations.success = true;
        result.data.authorsaffiliations.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.authorsaffiliations.recordcount# staging authorsaffiliations records with production");
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
        INSERT (author_id,year,works_count,cited_by_count,oa_works_count)
        VALUES (src.author_id,src.year,src.works_count,src.cited_by_count,src.oa_works_count)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authors_counts_by_year.success = true;
        result.data.authors_counts_by_year.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.authors_counts_by_year.recordcount# staging authors_counts_by_year records with production");
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
            dest.openalex=src.openalex,
            dest.orcid=src.orcid,
            dest.scopus=src.scopus,
            dest.twitter=src.twitter,
            dest.wikipedia=src.wikipedia,
            dest.mag=src.mag
    WHEN NOT MATCHED THEN
        INSERT (author_id,openalex,orcid,scopus,twitter,wikipedia,mag)
        VALUES (src.author_id,src.openalex,src.orcid,src.scopus,src.twitter,src.wikipedia,src.mag)",
        {},
        {datasource: getDatasource(), result: "qryresult"}
      );
      if (isStruct(qryresult)){
        result.data.authors_ids.success = true;
        result.data.authors_ids.recordcount = qryresult.recordcount;
        outputSuccess("Sucessfully merged #result.data.authors_ids.recordcount# staging authors_ids records with production");
      }
      else{
        result.success = false;
      }
    }

    flush;
    return result;
  }

  private any function logEntityImport(
    required entity,
    required updatedate,
    required filenumber,
    required filename,
    required fileurl,
    required totalfiles,
    required recordcount
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
            dest.createdat=current_timestamp
    WHEN NOT MATCHED THEN
        INSERT (entity, updatedate,filenumber,filename,fileurl,totalfiles,recordcount)
        VALUES (:entity,:updatedate,:filenumber,:filename,:fileurl,:totalfiles,:recordcount)
    ",
      {
        entity: {value: arguments.entity, cfsqltype: "varchar"},
        updatedate: {value: createODBCDate(arguments.updatedate), cfsqltype: "date"},
        filenumber: {value: arguments.filenumber, cfsqltype: "numeric"},
        filename: {value: arguments.filename, cfsqltype: "varchar"},
        fileurl: {value: arguments.fileurl, cfsqltype: "varchar"},
        totalfiles: {value: arguments.totalfiles, cfsqltype: "numeric"},
        recordcount: {value: arguments.recordcount, cfsqltype: "numeric"}
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
