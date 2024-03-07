load data 
characterset utf8
infile '.\csv\domainsids.csv'
BADFILE '.\logs\domainsids.bad'
DISCARDFILE '.\logs\domainsids.dsc'
truncate into table openalex.stage$domains_ids
Fields terminated by '\t' trailing nullcols
(
  DOMAIN_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WIKIDATA,
  WIKIPEDIA
)