load data 
characterset utf8
infile '.\csv\authorsids.csv'
BADFILE '.\logs\authorsids.bad'
DISCARDFILE '.\logs\authorsids.dsc'
truncate into table openalex.stage$authors_ids
Fields terminated by '\t' trailing nullcols
(
  AUTHOR_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  ORCID,
  SCOPUS,
  TWITTER,
  WIKIPEDIA,
  MAG
)