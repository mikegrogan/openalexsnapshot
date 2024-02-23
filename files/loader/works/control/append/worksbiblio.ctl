load data 
characterset utf8
infile '.\csv\worksbiblio.csv'
BADFILE '.\logs\worksbiblio.bad'
DISCARDFILE '.\logs\worksbiblio.dsc'
append into table openalex.works_biblio
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  VOLUME,
  ISSUE,
  FIRST_PAGE,
  LAST_PAGE
)