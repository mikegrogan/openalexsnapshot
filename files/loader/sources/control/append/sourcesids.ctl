load data 
characterset utf8
infile '.\csv\sourcesids.csv'
BADFILE '.\logs\sourcesids.bad'
DISCARDFILE '.\logs\sourcesids.dsc'
append into table openalex.sources_ids
Fields terminated by '\t' trailing nullcols
(
  SOURCE_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  ISSN_L,
  ISSN,
  MAG,
  WIKIDATA,
  FATCAT
)