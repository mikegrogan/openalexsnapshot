<cfscript>
api = new lib.OpenAlexClient();
api.main(
  syncAuthors = false,
  syncDomains = true,
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