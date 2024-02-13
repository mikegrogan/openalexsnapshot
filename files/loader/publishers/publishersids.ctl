load data 
characterset utf8
infile '.\csv\publishersids.csv'
BADFILE '.\logs\publishersids.bad'
DISCARDFILE '.\logs\publishersids.dsc'
truncate into table openalex.stage$publishers_ids
Fields terminated by '\t' trailing nullcols
(
  PUBLISHER_ID,
  OPENALEX,
  ROR,
  WIKIDATA
)