load data 
characterset utf8
infile '.\csv\fieldssiblings.csv'
BADFILE '.\logs\fieldssiblings.bad'
DISCARDFILE '.\logs\fieldssiblings.dsc'
truncate into table openalex.stage$fields_siblings
Fields terminated by '\t' trailing nullcols
(
  FIELD_ID,
  SIBLING_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)