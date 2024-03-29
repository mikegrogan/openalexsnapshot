/**
 * 
 * Used to download OpenAlex snapshost data
 * https://docs.openalex.org/download-all-data/openalex-snapshot
 *
 * @author Mike Grogan
 */
component accessors="true" extends="helper" {

  function init(){
    this.entity = new entity();

    return this;
  }

  /**
   * Pick which entities you want to sync. You  may not be interested in all of the Open Alex data,
   * so the option is given to only sync a subset.
   *
   * @syncAuthors
   * @syncConcepts
   * @syncFunders
   * @syncInstitutions
   * @syncPublishers
   * @syncSources
   * @syncWorks
   */
  public any function main(
    boolean syncAuthors = false,
    boolean syncDomains = false,
    boolean syncConcepts = false,
    boolean syncFields = false,
    boolean syncFunders = false,
    boolean syncInstitutions = false,
    boolean syncPublishers = false,
    boolean syncSources = false,
    boolean syncSubfields = false,
    boolean syncTopics = false,
    boolean syncWorks = false
  ){
    preSaveActions();

    var entityList = handleSyncArguments(arguments);

    if (entitylist.success){
      outputH1("Syncing the following Open Alex entities:");
      for (var entity in entitylist.data){
        outputNormal("<a href=""###entity#"">#entity#</a>");
      }
      // hand off work to entity component
      this.entity.handleEntities(entitylist = entityList.data);
    }

    postSaveActions();

    return this;
  }

  /**
   * Converts true values into a list
   * possible options: authors,concepts,domains,fields,funders,insititutions,publishers,sources,subfields,works
   *
   * @syncFlags
   */
  private struct function handleSyncArguments(syncFlags){
    var result = {success: false, data: ""};

    if (arguments.syncFlags.syncauthors){
      result.data = result.data.listAppend("authors");
    }
    if (arguments.syncFlags.syncconcepts){
      result.data = result.data.listAppend("concepts");
    }
    if (arguments.syncFlags.syncdomains){
      result.data = result.data.listAppend("domains");
    }
    if (arguments.syncflags.syncfields){
      result.data = result.data.listappend("fields");
    }
    if (arguments.syncflags.syncfunders){
      result.data = result.data.listappend("funders");
    }
    if (arguments.syncflags.syncinstitutions){
      result.data = result.data.listappend("institutions");
    }
    if (arguments.syncflags.syncpublishers){
      result.data = result.data.listappend("publishers");
    }
    if (arguments.syncflags.syncsources){
      result.data = result.data.listappend("sources");
    }
    if (arguments.syncflags.syncsubfields){
      result.data = result.data.listappend("subfields");
    }
    if (arguments.syncflags.synctopics){
      result.data = result.data.listappend("topics");
    }
    if (arguments.syncflags.syncworks){
      result.data = result.data.listappend("works");
    }

    if (result.data.len() !== 0){
      result.success = true;
    }


    return result;
  }

  /**
   * Script setup actions
   */
  public any function preSaveActions(){
    writeOutput("<link rel=""stylesheet"" href=""\#application.webpath#\assets\main.css"">");

    outputNormal("Script environment is #application.environment#. Change settings in your settings.json file.");

    // javascript output to update page as script progresses
    jSBookmarkFunction();
    // hoping to run merge queries in Oracle in parallel
    queryExecute("ALTER SESSION enable PARALLEL DML", {}, {datasource: getDatasource(), result: "qryresult"});
  }

  /**
   * Script complete actions
   */
  public any function postSaveActions(){
    queryExecute("ALTER SESSION disable PARALLEL DML", {}, {datasource: getDatasource(), result: "qryresult"});

    var runTimeInSeconds = dateDiff("s", getPageContext().GetFusionContext().GetStartTime(), now());
    var runTimeInMinutes = numberFormat(runTimeInSeconds / 60, ".__");
    outputImportant("Script took #runTimeInMinutes# minutes to run");
  }

}
