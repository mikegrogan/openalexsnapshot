load data 
characterset utf8
infile '.\csv\conceptsids.csv'
BADFILE '.\logs\conceptsids.bad'
DISCARDFILE '.\logs\conceptsids.dsc'
truncate into table openalex.stage$concepts_ids
Fields terminated by '\t' trailing nullcols
(
  CONCEPT_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  WIKIDATA,
  WIKIPEDIA CHAR(3000),
  UMLS_AUI CHAR(4000),
  UMLS_CUI CHAR(4000),
  MAG
)