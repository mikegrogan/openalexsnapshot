<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncDomains = false,
  syncConcepts = false,
  syncFields = false,
  syncFunders = false,
  syncInstitutions = false,
  syncPublishers = false,
  syncSources = false,
  syncSubfields = true,
  syncTopics = false,
  syncWorks = false
);
</cfscript>