load data 
characterset utf8
infile '.\csv\institutionsids.csv'
BADFILE '.\logs\institutionsids.bad'
DISCARDFILE '.\logs\institutionsids.dsc'
truncate into table openalex.stage$institutions_ids
Fields terminated by '\t' trailing nullcols
(
  INSTITUTION_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  ROR,
  GRID,
  WIKIPEDIA CHAR(3000),
  WIKIDATA,
  MAG
)