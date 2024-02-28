load data 
characterset utf8
infile '.\csv\publisherscountsbyyear.csv'
BADFILE '.\logs\publisherscountsbyyear.bad'
DISCARDFILE '.\logs\publisherscountsbyyear.dsc'
truncate into table openalex.stage$publishers_counts_by_year
Fields terminated by '\t' trailing nullcols
(
  PUBLISHER_ID,
  YEAR,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WORKS_COUNT,
  CITED_BY_COUNT,
  OA_WORKS_COUNT
)