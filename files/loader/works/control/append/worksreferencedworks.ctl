load data 
characterset utf8
infile '.\csv\worksreferencedworks.csv'
BADFILE '.\logs\worksreferencedworks.bad'
DISCARDFILE '.\logs\worksreferencedworks.dsc'
append into table openalex.works_referenced_works
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  REFERENCED_WORK_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)