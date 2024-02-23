load data 
characterset utf8
infile '.\csv\worksrelatedworks.csv'
BADFILE '.\logs\worksrelatedworks.bad'
DISCARDFILE '.\logs\worksrelatedworks.dsc'
truncate into table openalex.stage$works_related_works
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  RELATED_WORK_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)