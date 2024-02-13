component {

  this.name = "openalexsnapshot";

  this.applicationtimeout = createTimespan(1, 0, 0, 0);
  this.requestTimeout = 0;

  // TODO: Need to make sure /settings.json is mapped to the actual location,
  // which should be located outside of the web root!! Otherwise someone could load your password
  // information
  // e.g. (getDirectoryFromPath(getCurrentTemplatePath()) & "../../../../config/settings.json")
  this.mappings = {
    "/settings.json": (getDirectoryFromPath(getCurrentTemplatePath()) & "../../config/passwords/cron/settings.json")
  };

  function onApplicationStart(){
    // structClear(application);
    application.localpath = expandPath("files\");
    Application.openalexbaseurl = "https://openalex.s3.amazonaws.com/data/";

    getSettings();
  }

  function onRequestStart(){
    // if you want to refresh the application scope w/o restarting the server
    // onApplicationStart();
  }

  private function getSettings(){
    // enter values to overwrite config/settings.json
    Application.environment = ""; // something like local, development, production based on server
    Application.database = {};
    // example to overwrite json file
    // Application.database = {"connectionstring": "user/password@instance", "datasource": "vpr", "schema": "openalex"};

    try{
      // read settings from json file
      var settings = deserializeJSON(fileRead(expandPath("/settings.json")));
      if (!isNull(settings)){
        if (application.environment == ""){
          Application.environment = settings["environment"];
        }
        if (application.database.count() == 0){
          Application.database = settings["database"][Application.environment];
        }
      }
    }
    catch (any e){
      if (!findNoCase("does not exist", e.Message)){
        writeOutput("<div style='background-color:red; color: white; width:90%; padding:10px; top:0px; left:0px;'>settings.json file exists but contains errors. Default settings to be used. <BR/><BR/>#e.Message#<BR/></div>");
      }
    }
  }

}
