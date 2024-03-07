component accessors="true" {

  property name="startTime";

  function init(){
    return this;
  }

  public string function getRandomColor(){
    // var letters="0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F";

    var letters = "C,D,E";
    var listarry = listToArray(letters, ",");
    var color = "##";

    for (var i = 1; i <= 6; i++){
      var randomLetter = randRange(1, arrayLen(listarry));
      color = "#color##listarry[randomLetter]#";
    }

    return color;
  }

  public any function jSBookmarkFunction(){
    writeOutput(
      "
    <script>
      function updateBookmark(hashname){
        console.log(hashname);
        window.location.hash=hashname;
      }
    </script>
    "
    );
  }

  function deleteFile(filePath, includePath = true) hint="wraps in try/catch so it won't error"{
    var result = {success: true, message: ""};

    try{
      var directoryToDelete = getDirectoryFromPath(arguments.filepath);
      var filename = getFileFromPath(arguments.filepath);
      if (arguments.includePath){
        directoryDelete(directoryToDelete, true);
      }
      else{
        fileDelete(arguments.filePath);
      }
    }
    catch (any e){
      result.success = false;
      result.message = e.message;
    }

    if (result.success){
      outputSuccess("Deleted #filename# file originally located at #arguments.filepath#");
    }
    else{
      outputError("Unsucessfully deleted #filename# file located at #arguments.filepath#. Please remove manually.");
    }
    flush;

    return result;
  }

  function gunzipFile(infilePath, outfilePath, renameFileTo){
    var result = {success: true, message: "", filepath: "", filename: ""};

    outputh3("Uncompress file");
    outputNormal("Starting to uncompress file at #infilePath#");
    flush;

    var infile = "";
    var outfile = "";
    var gzInStream = createObject("java", "java.util.zip.GZIPInputStream");
    var outStream = createObject("java", "java.io.FileOutputStream");
    var inStream = createObject("java", "java.io.FileInputStream");
    var buffer = repeatString(" ", 1024).getBytes();
    var length = 0;

    if (right(arguments.infilePath, 3) neq ".gz") arguments.infilePath = arguments.infilePath & ".gz";

    try{
      infile = getFileFromPath(arguments.infilePath);
      outfile = arguments.outfilePath & left(infile, len(infile) - 3); // remove .gz
      result.filepath = outfile;
      result.filename = getFileFromPath(result.filepath);
      inStream.init(arguments.infilePath);
      gzInStream.init(inStream);
      outStream.init(outfile);

      do{
        length = gzInStream.read(buffer, 0, 1024);
        if (length !== -1) outStream.write(buffer, 0, length);
      }
      while (length !== -1);

      outStream.close();
      gzInStream.close();

      if (arguments.keyExists("renameFileTo") and arguments.renameFileTo !== ""){
        var newfilepath = getDirectoryFromPath(outfile) & arguments.renameFileTo;
        fileMove(outfile, newfilepath);
        result.filepath = newfilepath;
      }
    }
    catch (java.io.IOException e){
      result.message = e.message;
      result.success = false;

      writeOutput("Exception: " & e.message);

      try{
        outStream.close();
      }
      catch (java.io.IOException e){
        writeOutput("Error closing outStream: " & e.message);
      }

      try{
        gzInStream.close();
      }
      catch (java.io.IOException e){
        writeOutput("Error closing gzInStream: " & e.message);
      }
    }

    if (result.success){
      outputSuccess("Finished uncompressing file successfully to #result.filepath#");
      flush;
    }
    return result;
  }

  public any function deleteEntityCsvDirectory(entity){
    var result = {success: true};

    var csvDir = "#application.localpath#files\loader\#arguments.entity#\csv\";
    var fileList = directoryList(csvDir, false, "name", "*.csv");

    try{
      for (filename in filelist){
        fileDelete(csvDir & filename);
      }
    }
    catch (any e){
      result.success = false;
    }

    if (result.success){
      outputSuccess("Deleted entity #arguments.entity# CSV loader files");
    }

    return result;
  }

  public any function importDataToStaging(entity){
    var result = true;
    var importlist = this.tables.getActiveTableNamesList(arguments.entity);
    var importmode = this.tables.getEntityImportMode(arguments.entity);

    var tabletype = (importmode == "append") ? "main" : "staging";
    outputH3("Starting #arguments.entity# csv import into the #tabletype# tables");
    flush;

    cfexecute(
      name = "C:\WINDOWS\system32\WindowsPowerShell\v1.0\powershell.exe",
      arguments = "-File #application.localpath#files\loader\#arguments.entity#\run.ps1 -oraclepath #application.localpath#files\loader\#arguments.entity# -environment #application.environment# -importlist ""#importlist#"" -importmode ""#importmode#""",
      variable = "runoutput",
      errorVariable = "err",
      timeout = "1000"
    );

    if (variables.err !== ""){
      result = false;
      outputError(err);
    }
    else{
      if (runoutput.findNoCase("[Error]")){
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

  public string function getDatasource(){
    return application.database.datasource;
  }

  public string function getSchema(){
    return application.database.schema;
  }

  public string function getElapsedTime(elapsedTime) hint="in milliseconds. converts to minutes"{
    return "<span class=""elapsedtime"">#numberFormat(arguments.elapsedTime / 60000, "0.0000")# min</span>";
  }

  public string function getTimeStamp(resetElapsedTime = false){
    var elapsedTime = "";
    if (getStartTime() == ""){
      setStartTime(getTickCount());
    }
    else{
      elapsedTime = getTickCount() - getStartTime();
      if (arguments.keyExists("resetElapsedTime") && arguments.resetElapsedTime){
        setStartTime("");
      }
      setStartTime(getTickCount());
    }

    var result = "<span class=""timestamp"">#now().timeformat("h:mm:ss tt")#</span>";

    if (elapsedTime !== ""){
      result = result & getElapsedTime(elapsedTime);
    }

    return result;
  }

  public any function outputError(output){
    writeOutput("<div class=""error"">#output#</div>");
  }

  public any function outputWarning(output){
    writeOutput("<div class=""warning"">#output#</div>");
  }

  public any function outputSuccess(output){
    writeOutput("<div class=""success"">#output#</div>");
  }

  public any function outputNormal(output){
    writeOutput("<div class=""normal"">#output#</div>");
  }

  private any function outputImportant(output){
    writeOutput("<div class=""important"">#output#</div>");
  }

  public any function outputH1(output){
    writeOutput("<h1>#output#</h1>");
  }

  public any function outputH2(output){
    writeOutput("<h2>#output#</h2>");
  }

  public any function outputH3(output){
    writeOutput("<h3>#getTimeStamp()# #output#</h3>");
  }

  public any function outputH4(output){
    writeOutput("<h4>#getTimeStamp()# #output#</h4>");
  }

}
