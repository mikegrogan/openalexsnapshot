load data 
characterset utf8
infile '.\csv\authors.csv'
BADFILE '.\logs\authors.bad'
DISCARDFILE '.\logs\authors.dsc'
truncate into table openalex.stage$authors
Fields terminated by '\t' trailing nullcols
(
  ID,
  ORCID,
  DISPLAY_NAME,
  DISPLAY_NAME_ALTERNATIVES CHAR(4000),
  WORKS_COUNT,
  CITED_BY_COUNT,
  LAST_KNOWN_INSTITUTION,
  WORKS_API_URL,
  UPDATED_DATE TIMESTAMP 'YYYY-MM-DD"T"HH24:MI:SS.FF'
)