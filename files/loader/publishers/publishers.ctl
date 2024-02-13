load data 
characterset utf8
infile '.\csv\publishers.csv'
BADFILE '.\logs\publishers.bad'
DISCARDFILE '.\logs\publishers.dsc'
truncate into table openalex.stage$publishers
Fields terminated by '\t' trailing nullcols
(
  ID,
  DISPLAY_NAME CHAR(1000),
  ALTERNATE_TITLES CHAR(8000),
  COUNTRY_CODES CHAR(4000),
  HIERARCHY_LEVEL,
  PARENT_PUBLISHER,
  WORKS_COUNT,
  CITED_BY_COUNT,
  SOURCES_API_URL,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)