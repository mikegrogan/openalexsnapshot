load data 
characterset utf8
infile '.\csv\worksauthorships.csv'
BADFILE '.\logs\worksauthorships.bad'
DISCARDFILE '.\logs\worksauthorships.dsc'
append into table openalex.works_authorships
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  AUTHOR_POSITION,
  AUTHOR_ID,
  RAW_AUTHOR_NAME CHAR(3000),
  INSTITUTION_ID,
  RAW_AFFILIATION_STRING CHAR(8000)
)