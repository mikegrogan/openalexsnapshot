load data 
characterset utf8
infile '.\csv\authorslastinstitutions.csv'
BADFILE '.\logs\authorslastinstitutions.bad'
DISCARDFILE '.\logs\authorslastinstitutions.dsc'
append into table openalex.authors_lastinstitutions
Fields terminated by '\t' trailing nullcols
(
  AUTHOR_ID,
  INSTITUTION_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)