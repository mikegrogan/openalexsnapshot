<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncConcepts = false,
  syncFunders = false,
  syncInstitutions = true,
  syncPublishers = false,
  syncSources = false,
  syncWorks = false
);
</cfscript>
