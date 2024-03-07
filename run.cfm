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
  syncSubfields = false,
  syncTopics = true,
  syncWorks = false
);
</cfscript>