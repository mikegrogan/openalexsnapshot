load data 
characterset utf8
infile '.\csv\fundersids.csv'
BADFILE '.\logs\fundersids.bad'
DISCARDFILE '.\logs\fundersids.dsc'
truncate into table openalex.stage$funders_ids
Fields terminated by '\t' trailing nullcols
(
  FUNDER_ID,
  OPENALEX,
  ROR,
  WIKIDATA,
  CROSSREF,
  DOI
)