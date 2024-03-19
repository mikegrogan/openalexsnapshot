<cfscript>
api = new lib.OpenAlexClient();
api.main(
  syncAuthors = true,
  syncDomains = false,
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