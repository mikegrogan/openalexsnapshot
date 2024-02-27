load data 
characterset utf8
infile '.\csv\institutions.csv'
BADFILE '.\logs\institutions.bad'
DISCARDFILE '.\logs\institutions.dsc'
truncate into table openalex.stage$institutions
Fields terminated by '\t' trailing nullcols
(
  ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  ROR,
  DISPLAY_NAME CHAR(1000),
  COUNTRY_CODE,
  TYPE,
  HOMEPAGE_URL CHAR(1000),
  IMAGE_URL CHAR(1000),
  IMAGE_THUMBNAIL_URL CHAR(1000),
  DISPLAY_NAME_ACRONYMS CHAR(4000),
  DISPLAY_NAME_ALTERNATIVES CHAR(4000),
  WORKS_COUNT,
  CITED_BY_COUNT,
  WORKS_API_URL,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)