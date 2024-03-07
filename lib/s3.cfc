component extends="helper" {

  function init(){
    return this;
  }

  public any function streamFileFromOA(externalFile, localFile){
    var result = {success: false};

    // Open the URL stream
    var urlStream = createObject("java", "java.net.URL").init(externalFile).openStream();

    // Open a file stream to write the content
    var fileOutputStream = createObject("java", "java.io.FileOutputStream").init(localFile);
    var bufferedOutputStream = createObject("java", "java.io.BufferedOutputStream").init(fileOutputStream);

    // Open a buffered stream for the URL
    var bufferedInputStream = createObject("java", "java.io.BufferedInputStream").init(urlStream);

    // Set the buffer size (adjust as needed)
    var bufferSize = 8192;
    var buffer = createObject("java", "java.lang.reflect.Array").newInstance(
      createObject("java", "java.lang.Byte").TYPE,
      bufferSize
    );

    try{
      // Read and write content in chunks
      while (true){
        var readBytes = bufferedInputStream.read(buffer);
        if (readBytes == -1){
          break;
        }
        bufferedOutputStream.write(buffer, 0, readBytes);
      }
    }
    finally{
      result.success = true;
      // Close the streams
      bufferedInputStream.close();
      bufferedOutputStream.close();
      urlStream.close();
    }
    return result;
  }

  public any function downloadFileFromOA(externalFile, localFile, boolean returnData = false){
    var result = {success: false, message: "", data: ""};

    var httpRequest = new http();
    httpRequest.setURL(arguments.externalFile);
    httpRequest.setMethod("GET");
    httpRequest.addParam(
      type = "header",
      name = "User-Agent",
      value = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    );

    // Execute the HTTP request
    var httpResult = httpRequest.send().getPrefix();
    // Check for a successful response
    if (findNoCase("200", httpResult.statusCode)){
      fileContent = httpResult.fileContent;

      if (arguments.returnData){
        result.data = fileContent.toString("utf-8");
      }
      else{
        fileWrite(arguments.localFile, fileContent, "utf-8");
      }
      result.success = true;
    }
    else{
      // Handle the case where the request was not successful
      writeOutput("Error: " & result.statusCode);
      // result.message = result.message;
    }
    return result;
  }

  public any function downloadEntityManifestFromOA(string entity){
    var result = {success: true};

    for (manifest in arguments.entity){
      var externalfile = application.openalexbaseurl & manifest & "/manifest";
      var localfile = application.localpath & "files\manifest\" & manifest & ".json";
      var downloadResult = downloadFileFromOA(externalFile = externalfile, returnData = true);

      // want to sort the manifest so it's easier to read
      var manifestJson = downloadResult.data.deserializeJSON();
      manifestJson.entries = manifestJson.entries.sort(function(e1, e2){
        return compare(e1.url, e2.url);
      });

      fileWrite(localFile, manifestJson.tojson(), "utf-8");

      outputSuccess("Downloaded (and sorted) the #manifest# manifest file to #localfile#.");
      outputNormal("Found #numberFormat(manifestJson.meta.record_count)# total #manifest# records in OpenAlex in #manifestJson.entries.len()# snapshot files.");
      flush;
      if (!downloadResult.success){
        result.success = false;
        break;
      }
    }

    return result;
  }

  public any function downloadMergedManifestFromOA(required entity){
    var result = {success: false, data: []};

    var httpRequest = new http();
    httpRequest.setURL("https://openalex.s3.amazonaws.com/?list-type=2&delimiter=%2F&prefix=data%2Fmerged_ids%2F#arguments.entity#%2F");
    httpRequest.setMethod("GET");
    httpRequest.addParam(
      type = "header",
      name = "User-Agent",
      value = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    );

    var httpResult = httpRequest.send().getPrefix();
    var xmlResult = xmlParse(httpResult.filecontent);
    var xmlContents = xmlSearch(xmlResult, "//*[local-name()='Contents']");

    result.data = [];
    for (var xmlchild in xmlContents){
      var elements = xmlChild.XmlChildren;

      var contentUrl = application.openalexbaseurl & elements.filter((item) => {
        return item["XmlName"] == "Key";
      })[1].xmltext.reReplaceNoCase("data/", "");

      var updateDate = "";
      var updateYear = "";
      var updateMonth = "";
      var updateDay = "";
      var filename = contentUrl.listLast("/");
      var updatedateFind = reFindNoCase("(\d{4}-\d{2}-\d{2})", filename, 0, true);

      if (
        isStruct(updatedateFind) && updatedateFind.keyExists("match") && isArray(updatedateFind.match) && updatedateFind.match.len() == 2
      ){
        updateDate = updatedateFind.match[2];
        updateYear = listFirst(updateDate, "-");
        updateMonth = listGetAt(updateDate, 2, "-")
        updateDay = listLast(updateDate, "-");
      }

      if (filename.findNoCase(".csv.gz") > 0){
        result.data.append({
          "meta": {
            "content_length": elements.filter((item) => {
              return item["XmlName"] == "Size";
            })[1].xmltext,
            "lastmodified": elements.filter((item) => {
              return item["XmlName"] == "LastModified";
            })[1].xmltext,
            "etag": elements.filter((item) => {
              return item["XmlName"] == "ETag";
            })[1].xmltext.reReplaceNoCase("""", "", "all")
          },
          "url": contentUrl,
          "filename": filename,
          "updateDate": updateDate,
          "updateYear": updateYear,
          "updateMonth": updateMonth,
          "updateDay": updateDay
        });
      }
    }

    if (result.data.len() > 0){
      result.success = true;
    }

    var localfile = application.localpath & "files\manifest\" & entity & "_merged.json";
    result.data = result.data.sort(function(e1, e2){
      return compare(e1.url, e2.url);
    });

    // save manifest to filesystem for review
    fileWrite(localFile, result.data.tojson(), "utf-8");

    outputSuccess("Created (and sorted) the #entity# merged manifest file to #localfile#.");
    outputNormal("Found #result.data.len()# merge csv files.");
    flush;

    return result;
  }

}
