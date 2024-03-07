<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncDomains = false,
  syncConcepts = false,
  syncFields = true,
  syncFunders = false,
  syncInstitutions = false,
  syncPublishers = false,
  syncSources = false,
  syncSubfields = false,
  syncTopics = false,
  syncWorks = false
);
</cfscript>