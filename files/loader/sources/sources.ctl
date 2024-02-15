load data 
characterset utf8
infile '.\csv\sources.csv'
BADFILE '.\logs\sources.bad'
DISCARDFILE '.\logs\sources.dsc'
truncate into table openalex.stage$sources
Fields terminated by '\t' trailing nullcols
(
  ID,
  ISSN_L,
  ISSN CHAR(4000),
  DISPLAY_NAME CHAR(1500),
  PUBLISHER,
  WORKS_COUNT,
  CITED_BY_COUNT,
  IS_OA,
  IS_IN_DOAJ,
  HOMEPAGE_URL CHAR(1000),
  WORKS_API_URL CHAR(1000),
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)