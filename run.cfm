<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncConcepts = false,
  syncFunders = false,
  syncInstitutions = false,
  syncPublishers = true,
  syncSources = false,
  syncWorks = false
);
</cfscript>
