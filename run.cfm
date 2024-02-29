<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncConcepts = false,
  syncFunders = false,
  syncInstitutions = false,
  syncPublishers = false,
  syncSources = true,
  syncWorks = false
);
</cfscript>
