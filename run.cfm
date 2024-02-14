<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = true,
  syncConcepts = false,
  syncFunders = false,
  syncInstitutions = false,
  syncPublishers = false,
  syncSources = false,
  syncWorks = false
);
</cfscript>
