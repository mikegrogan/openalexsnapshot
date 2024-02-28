load data 
characterset utf8
infile '.\csv\publishersids.csv'
BADFILE '.\logs\publishersids.bad'
DISCARDFILE '.\logs\publishersids.dsc'
append into table openalex.publishers_ids
Fields terminated by '\t' trailing nullcols
(
  PUBLISHER_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  ROR,
  WIKIDATA
)