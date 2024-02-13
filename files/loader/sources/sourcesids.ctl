load data 
characterset utf8
infile '.\csv\sourcesids.csv'
BADFILE '.\logs\sourcesids.bad'
DISCARDFILE '.\logs\sourcesids.dsc'
truncate into table openalex.stage$sources_ids
Fields terminated by '\t' trailing nullcols
(
  SOURCE_ID,
  OPENALEX,
  ISSN_L,
  ISSN,
  MAG,
  WIKIDATA,
  FATCAT
)