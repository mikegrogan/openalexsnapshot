load data 
characterset utf8
infile '.\csv\domainsfields.csv'
BADFILE '.\logs\domainsfields.bad'
DISCARDFILE '.\logs\domainsfields.dsc'
truncate into table openalex.stage$domains_fields
Fields terminated by '\t' trailing nullcols
(
  DOMAIN_ID,
  FIELD_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)