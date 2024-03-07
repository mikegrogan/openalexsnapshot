load data 
characterset utf8
infile '.\csv\subfieldssiblings.csv'
BADFILE '.\logs\subfieldssiblings.bad'
DISCARDFILE '.\logs\subfieldssiblings.dsc'
append into table openalex.subfields_siblings
Fields terminated by '\t' trailing nullcols
(
  SUBFIELD_ID,
  SIBLING_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)