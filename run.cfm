<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncConcepts = false,
  syncFunders = true,
  syncInstitutions = false,
  syncPublishers = false,
  syncSources = false,
  syncWorks = false
);
</cfscript>
