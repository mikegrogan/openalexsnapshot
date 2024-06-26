load data 
characterset utf8
infile '.\csv\funders.csv'
BADFILE '.\logs\funders.bad'
DISCARDFILE '.\logs\funders.dsc'
append into table openalex.funders
Fields terminated by '\t' trailing nullcols
(
  ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  DISPLAY_NAME CHAR(1500),
  ALTERNATE_TITLES CHAR(5000),
  COUNTRY_CODE,
  DESCRIPTION CHAR(500),
  HOMEPAGE_URL CHAR(1000),
  IMAGE_URL CHAR(1000),
  IMAGE_THUMBNAIL_URL CHAR(1000),
  GRANTS_COUNT,
  WORKS_COUNT,
  CITED_BY_COUNT,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)