load data 
characterset utf8
infile '.\csv\worksauthorships.csv'
BADFILE '.\logs\worksauthorships.bad'
DISCARDFILE '.\logs\worksauthorships.dsc'
truncate into table openalex.stage$works_authorships
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  AUTHOR_POSITION,
  AUTHOR_ID,
  INSTITUTION_ID,
  RAW_AFFILIATION_STRING CHAR(8000)
)