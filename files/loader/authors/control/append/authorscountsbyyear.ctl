load data 
characterset utf8
infile '.\csv\authorscountsbyyear.csv'
BADFILE '.\logs\authorscountsbyyear.bad'
DISCARDFILE '.\logs\authorscountsbyyear.dsc'
append into table openalex.authors_counts_by_year
Fields terminated by '\t' trailing nullcols
(
  AUTHOR_ID,
  YEAR,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WORKS_COUNT,
  CITED_BY_COUNT,
  OA_WORKS_COUNT
)