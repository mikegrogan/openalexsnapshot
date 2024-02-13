load data 
characterset utf8
infile '.\csv\institutionsids.csv'
BADFILE '.\logs\institutionsids.bad'
DISCARDFILE '.\logs\institutionsids.dsc'
truncate into table openalex.stage$institutions_ids
Fields terminated by '\t' trailing nullcols
(
  INSTITUTION_ID,
  OPENALEX,
  ROR,
  GRID,
  WIKIPEDIA CHAR(1000),
  WIKIDATA,
  MAG
)