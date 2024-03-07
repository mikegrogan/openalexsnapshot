load data 
characterset utf8
infile '.\csv\domainssiblings.csv'
BADFILE '.\logs\domainssiblings.bad'
DISCARDFILE '.\logs\domainssiblings.dsc'
truncate into table openalex.stage$domains_siblings
Fields terminated by '\t' trailing nullcols
(
  DOMAIN_ID,
  SIBLING_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)