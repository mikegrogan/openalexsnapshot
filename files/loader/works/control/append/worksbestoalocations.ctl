load data 
characterset utf8
infile '.\csv\worksbestoalocations.csv'
BADFILE '.\logs\worksbestoalocations.bad'
DISCARDFILE '.\logs\worksbestoalocations.dsc'
append into table openalex.works_best_oa_locations
Fields terminated by '\t' trailing nullcols
(
  UNIQUE_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WORK_ID,
  SOURCE_ID,
  LANDING_PAGE_URL CHAR(1000),
  PDF_URL CHAR(3000),
  IS_OA,
  VERSION,
  LICENSE
)