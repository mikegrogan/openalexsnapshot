load data 
characterset utf8
infile '.\csv\worksbestoalocations.csv'
BADFILE '.\logs\worksbestoalocations.bad'
DISCARDFILE '.\logs\worksbestoalocations.dsc'
truncate into table openalex.stage$works_best_oa_locations
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  SOURCE_ID,
  LANDING_PAGE_URL CHAR(1000),
  PDF_URL CHAR(1500),
  IS_OA,
  VERSION,
  LICENSE
)