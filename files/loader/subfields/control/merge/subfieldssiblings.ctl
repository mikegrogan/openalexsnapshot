load data 
characterset utf8
infile '.\csv\subfieldssiblings.csv'
BADFILE '.\logs\subfieldssiblings.bad'
DISCARDFILE '.\logs\subfieldssiblings.dsc'
truncate into table openalex.stage$subfields_siblings
Fields terminated by '\t' trailing nullcols
(
  SUBFIELD_ID,
  SIBLING_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)