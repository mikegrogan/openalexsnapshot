load data 
characterset utf8
infile '.\csv\domainssiblings.csv'
BADFILE '.\logs\domainssiblings.bad'
DISCARDFILE '.\logs\domainssiblings.dsc'
append into table openalex.domains_siblings
Fields terminated by '\t' trailing nullcols
(
  DOMAIN_ID,
  SIBLING_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)