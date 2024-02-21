load data 
characterset utf8
infile '.\csv\workslocations.csv'
BADFILE '.\logs\workslocations.bad'
DISCARDFILE '.\logs\workslocations.dsc'
truncate into table openalex.stage$works_locations
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  SOURCE_ID,
  LANDING_PAGE_URL CHAR(1000),
  PDF_URL CHAR(1000),
  IS_OA,
  VERSION,
  LICENSE
)