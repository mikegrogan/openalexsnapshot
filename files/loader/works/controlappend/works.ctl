load data 
characterset utf8
infile '.\csv\works.csv'
BADFILE '.\logs\works.bad'
DISCARDFILE '.\logs\works.dsc'
append into table openalex.works
Fields terminated by '\t' trailing nullcols
(
  ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  DOI CHAR(300),
  TITLE CHAR(1500),
  DISPLAY_NAME CHAR(1500),
  PUBLICATION_YEAR,
  PUBLICATION_DATE Date "YYYY-MM-DD",
  TYPE,
  CITED_BY_COUNT,
  IS_RETRACTED,
  IS_PARATEXT,
  CITED_BY_API_URL,
  LANGUAGE
)