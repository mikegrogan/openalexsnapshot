<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = true,
  syncConcepts = true,
  syncFunders = true,
  syncInstitutions = true,
  syncPublishers = true,
  syncSources = true,
  syncWorks = true
);
</cfscript>
