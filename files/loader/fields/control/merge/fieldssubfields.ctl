load data 
characterset utf8
infile '.\csv\fieldssubfields.csv'
BADFILE '.\logs\fieldssubfields.bad'
DISCARDFILE '.\logs\fieldssubfields.dsc'
truncate into table openalex.stage$fields_subfields
Fields terminated by '\t' trailing nullcols
(
  FIELD_ID,
  SUBFIELD_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)