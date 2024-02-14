load data 
characterset utf8
infile '.\csv\funders.csv'
BADFILE '.\logs\funders.bad'
DISCARDFILE '.\logs\funders.dsc'
truncate into table openalex.stage$funders
Fields terminated by '\t' trailing nullcols
(
  ID,
  DISPLAY_NAME,
  ALTERNATE_TITLES CHAR(5000),
  COUNTRY_CODE,
  DESCRIPTION,
  HOMEPAGE_URL,
  IMAGE_URL CHAR(1000),
  IMAGE_THUMBNAIL_URL CHAR(1000),
  GRANTS_COUNT,
  WORKS_COUNT,
  CITED_BY_COUNT,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)