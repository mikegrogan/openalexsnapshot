load data 
characterset utf8
infile '.\csv\fundersids.csv'
BADFILE '.\logs\fundersids.bad'
DISCARDFILE '.\logs\fundersids.dsc'
append into table openalex.funders_ids
Fields terminated by '\t' trailing nullcols
(
  FUNDER_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  ROR,
  WIKIDATA,
  CROSSREF,
  DOI
)