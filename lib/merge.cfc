component accessors="true" extends="helper" {

  function init(){
    this.s3 = new s3();
    this.tables = new tableSchema();
    return this;
  }

  public any function processEntityMergedIds(required entity){
    // funds / concepts don't have merged_ids (yet?);
    var result = {success: false};

    var filesToProcess = getMergedFilesNotComplete(entity = arguments.entity);

    if (!filesToProcess.success){
      result.success = true;
    }
    else{
      if (filesToProcess.data.len() > 0){
        outputH2("Processing remaining #arguments.entity# merged data to delete");
      }
      else{
        outputImportant("All up to date with #arguments.entity# merged data to delete");
        result.success = true;
      }
      var limit = 0;
      for (var merged in filestoprocess.data){
        writeOutput("<div id=""merge-#arguments.entity#-#dateFormat(merged.updateDate, "yyyy-mm-dd")#"" class=""snapshot"" style=""background-color:#getRandomColor()#;"">");
        outputH2("#uCase(arguments.entity)# Merged &##10142; #dateFormat(merged.updateDate, "yyyy-mm-dd")# &##10142; #uCase(merged.filename)#");

        var compressedFilePath = application.localpath & "files\compressed\#merged.updateDate#\#merged.filename#";
        if (!directoryExists(getDirectoryFromPath(compressedFilePath))){
          directoryCreate(getDirectoryFromPath(compressedFilePath));
        }
        outputh3("Download Compressed File");

        outputNormal("Starting to download file located at #merged.url#");
        flush;
        var compressedFile = this.s3.streamFileFromOA(merged.url, compressedFilePath);
        if (compressedFile.success){
          outputSuccess("Finished downloading compressed file to #compressedFilePath#");
          flush;
          var uncompressedPath = application.localpath & "files\loader\mergeids\csv\";

          if (!directoryExists(uncompressedPath)){
            directoryCreate(uncompressedPath);
          }

          var unCompressedFile = gunzipFile(compressedFilePath, uncompressedPath, "mergeids.csv");

          if (unCompressedFile.success){
            deleteFile(compressedFilePath, true);

            var imported = importDataToStaging(entity = "mergeids");
            if (!imported){
              outputError("There was an error during the database import. Script has been halted. Please review the \files\loader\mergeids\logs folder for more details");
              break;
            }
            else{
              var processed = processMergeData(entity = arguments.entity);
              if (processed.success){
                deleteFile(unCompressedFile.filepath, false);

                logMergeDelete(
                  entity = arguments.entity,
                  updatedate = merged.updateDate,
                  filename = merged.filename,
                  fileurl = merged.url
                );
                result.success = true;
              }
            }
          }
        }
        writeOutput("</div><script>updateBookmark(""merge-#arguments.entity#-#dateFormat(merged.updateDate, "yyyy-mm-dd""")#)</script>");
      }
    }
    return result;
  }

  private any function logMergeDelete(required entity, required updatedate, required filename, required fileurl){
    var result = {success: false};

    queryExecute(
      "MERGE INTO #getSchema()#.entitymergelatestsync dest
    USING (
      select '#arguments.entity#' as entity from dual) src
    ON (dest.entity = src.entity)
    WHEN MATCHED THEN
        UPDATE SET
            dest.updatedate = :updatedate,
            dest.filename=:filename,
            dest.fileurl=:fileurl,
            dest.createdat=current_timestamp
    WHEN NOT MATCHED THEN
        INSERT (entity, updatedate,filename,fileurl)
        VALUES (:entity,:updatedate,:filename,:fileurl)
    ",
      {
        entity: {value: arguments.entity, cfsqltype: "varchar"},
        updatedate: {value: createODBCDate(arguments.updatedate), cfsqltype: "date"},
        filename: {value: arguments.filename, cfsqltype: "varchar"},
        fileurl: {value: arguments.fileurl, cfsqltype: "varchar"}
      },
      {datasource: getDatasource(), result: "qryresult"}
    );

    if (isStruct(qryResult)){
      result.success = true;
      outputSuccess("Logged merged sync results to database");
    }
    return result;
  }

  private struct function getMergedFilesNotComplete(entity){
    var result = this.s3.downloadMergedManifestFromOA(entity = arguments.entity);

    // defaults that will return everything
    var compareDate = createDate(1900, 1, 1);

    var latest = getLatestMergeFileSynced(entity = arguments.entity);

    if (latest.recordcount == 1){
      compareDate = latest.updateDate;
      outputNormal("Latest synced #arguments.entity# merge file found is #dateFormat(compareDate, "yyyy-mm-dd")# &##10142; #latest.filename#");
    }

    result.data = result.data.filter((row) => {
      return dateCompare(row.updateDate, compareDate, "d") == 1;
    });

    return result;
  }

  private any function getLatestMergeFileSynced(entity){
    return queryExecute(
      "select *
    from #getSchema()#.entitymergelatestsync
    where entity=:entity",
      {entity: {value: arguments.entity, cfsqltype: "varchar"}},
      {datasource: getDatasource(), result: "qryresult"}
    );
  }

  private any function processMergeData(entity){
    var result = {success: true};

    outputh3("Delete merge records from tables");
    flush;

    // currently won't delete ids from non active tables. think this is the
    // best approach just in case the table doesn't exist.
    for (var table in this.tables.getActiveTables(arguments.entity)){
      queryExecute(
        "delete from #getSchema()#.#table.name#
        where #table.id# in (select id from #getSchema()#.stage$mergeids)",
        {},
        {datasource: getDatasource(), result: "mergeQryResult"}
      );

      if (isStruct(mergeQryResult)){
        outputSuccess("Deleted #mergeQryResult.recordcount# merged records from #table.name#");
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

}
