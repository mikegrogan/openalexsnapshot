load data 
characterset utf8
infile '.\csv\fieldsids.csv'
BADFILE '.\logs\fieldsids.bad'
DISCARDFILE '.\logs\fieldsids.dsc'
truncate into table openalex.stage$fields_ids
Fields terminated by '\t' trailing nullcols
(
  FIELD_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WIKIDATA,
  WIKIPEDIA
)