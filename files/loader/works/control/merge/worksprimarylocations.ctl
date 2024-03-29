load data 
characterset utf8
infile '.\csv\worksprimarylocations.csv'
BADFILE '.\logs\worksprimarylocations.bad'
DISCARDFILE '.\logs\worksprimarylocations.dsc'
truncate into table openalex.stage$works_primary_locations
Fields terminated by '\t' trailing nullcols
(
  UNIQUE_ID,
  WORK_ID,
  SOURCE_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  LANDING_PAGE_URL CHAR(2000),
  PDF_URL CHAR(3000),
  IS_OA,
  VERSION,
  LICENSE
)