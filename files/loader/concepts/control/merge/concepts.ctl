load data 
characterset utf8
infile '.\csv\concepts.csv'
BADFILE '.\logs\concepts.bad'
DISCARDFILE '.\logs\concepts.dsc'
truncate into table openalex.stage$concepts
Fields terminated by '\t' trailing nullcols
(
  ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WIKIDATA,
  DISPLAY_NAME CHAR(1000),
  CONCEPT_LEVEL,
  DESCRIPTION CHAR(500),
  WORKS_COUNT,
  CITED_BY_COUNT,
  IMAGE_URL CHAR(1000),
  IMAGE_THUMBNAIL_URL CHAR(1000),
  WORKS_API_URL,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)