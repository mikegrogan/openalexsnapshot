<cfscript>
  // append mode disables primary table constraints. If something fails and the 
  // primary key becomes unstable it might be necessary to reindex them. You can do that 
  // directly in the database, or this is a helper script to do it as well

  // Just update the entity as necessary and run in a browser

  api = new lib.tableSchema();
  api.rebuildPrimaryKeyIndex(entity="works");
</cfscript>