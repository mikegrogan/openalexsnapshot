load data 
characterset utf8
infile '.\csv\workslocations.csv'
BADFILE '.\logs\workslocations.bad'
DISCARDFILE '.\logs\workslocations.dsc'
append into table openalex.works_locations
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  SOURCE_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  LANDING_PAGE_URL CHAR(1000),
  PDF_URL CHAR(1000),
  IS_OA,
  VERSION,
  LICENSE
)