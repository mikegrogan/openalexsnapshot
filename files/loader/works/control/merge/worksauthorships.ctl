load data 
characterset utf8
infile '.\csv\worksauthorships.csv'
BADFILE '.\logs\worksauthorships.bad'
DISCARDFILE '.\logs\worksauthorships.dsc'
truncate into table openalex.stage$works_authorships
Fields terminated by '\t' trailing nullcols
(
  UNIQUE_ID,
  WORK_ID,
  AUTHOR_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  AUTHOR_POSITION,
  RAW_AUTHOR_NAME CHAR(8000),
  INSTITUTION_ID,
  RAW_AFFILIATION_STRING CHAR(8000)
)