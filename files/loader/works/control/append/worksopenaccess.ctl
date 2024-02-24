load data 
characterset utf8
infile '.\csv\worksopenaccess.csv'
BADFILE '.\logs\worksopenaccess.bad'
DISCARDFILE '.\logs\worksopenaccess.dsc'
append into table openalex.works_open_access
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  IS_OA,
  OA_STATUS,
  OA_URL char(3000),
  ANY_REPOSITORY_HAS_FULLTEXT
)