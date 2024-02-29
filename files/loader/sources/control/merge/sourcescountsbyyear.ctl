load data 
characterset utf8
infile '.\csv\sourcescountsbyyear.csv'
BADFILE '.\logs\sourcescountsbyyear.bad'
DISCARDFILE '.\logs\sourcescountsbyyear.dsc'
truncate into table openalex.stage$sources_counts_by_year
Fields terminated by '\t' trailing nullcols
(
  SOURCE_ID,
  YEAR,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WORKS_COUNT,
  CITED_BY_COUNT,
  OA_WORKS_COUNT
)