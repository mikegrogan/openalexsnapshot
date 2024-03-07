load data 
characterset utf8
infile '.\csv\domains.csv'
BADFILE '.\logs\domains.bad'
DISCARDFILE '.\logs\domains.dsc'
truncate into table openalex.stage$domains
Fields terminated by '\t' trailing nullcols
(
  ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  DISPLAY_NAME CHAR(1000),
  DISPLAY_NAME_ALTERNATIVES CHAR(2000),
  DESCRIPTION CHAR(1000),
  WORKS_COUNT,
  CITED_BY_COUNT,
  WORKS_API_URL,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)