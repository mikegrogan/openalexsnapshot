load data 
characterset utf8
infile '.\csv\funderscountsbyyear.csv'
BADFILE '.\logs\funderscountsbyyear.bad'
DISCARDFILE '.\logs\funderscountsbyyear.dsc'
append into table openalex.funders_counts_by_year
Fields terminated by '\t' trailing nullcols
(
  FUNDER_ID,
  YEAR,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  WORKS_COUNT,
  CITED_BY_COUNT
)