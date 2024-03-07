load data 
characterset utf8
infile '.\csv\subfieldsids.csv'
BADFILE '.\logs\subfieldsids.bad'
DISCARDFILE '.\logs\subfieldsids.dsc'
truncate into table openalex.stage$subfields_ids
Fields terminated by '\t' trailing nullcols
(
  SUBFIELD_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WIKIDATA,
  WIKIPEDIA
)