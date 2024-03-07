<cfscript>
api = new OpenAlexClient();
api.main(
  syncAuthors = false,
  syncDomains = true,
  syncConcepts = false,
  syncFields = false,
  syncFunders = false,
  syncInstitutions = false,
  syncPublishers = false,
  syncSources = false,
  syncSubfields = false,
  syncTopics = false,
  syncWorks = false
);
</cfscript>