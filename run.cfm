<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncConcepts = false,
  syncFunders = false,
  syncInstitutions = false,
  syncPublishers = false,
  syncSources = false,
  syncWorks = true
);
</cfscript>
