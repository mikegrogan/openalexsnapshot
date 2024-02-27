<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncConcepts = true,
  syncFunders = false,
  syncInstitutions = false,
  syncPublishers = false,
  syncSources = false,
  syncWorks = false
);
</cfscript>
