load data 
characterset utf8
infile '.\csv\topics.csv'
BADFILE '.\logs\topics.bad'
DISCARDFILE '.\logs\topics.dsc'
truncate into table openalex.stage$topics
Fields terminated by '\t' trailing nullcols
(
  ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  DISPLAY_NAME CHAR(1000),
  DESCRIPTION CHAR(500),
  KEYWORDS CHAR(2000),
  SUBFIELD_ID,
  FIELD_ID,
  DOMAIN_ID,
  WORKS_COUNT,
  CITED_BY_COUNT,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)