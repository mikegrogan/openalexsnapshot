load data 
characterset utf8
infile '.\csv\subfields.csv'
BADFILE '.\logs\subfields.bad'
DISCARDFILE '.\logs\subfields.dsc'
APPEND into table openalex.subfields
Fields terminated by '\t' trailing nullcols
(
  ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  DISPLAY_NAME CHAR(1000),
  DISPLAY_NAME_ALTERNATIVES CHAR(2000),
  DESCRIPTION CHAR(1000),
  FIELD_ID,  
  DOMAIN_ID,
  WORKS_COUNT,
  CITED_BY_COUNT,
  WORKS_API_URL,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)