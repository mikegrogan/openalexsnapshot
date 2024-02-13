load data 
characterset utf8
infile '.\csv\funderscountsbyyear.csv'
BADFILE '.\logs\funderscountsbyyear.bad'
DISCARDFILE '.\logs\funderscountsbyyear.dsc'
truncate into table openalex.stage$funders_counts_by_year
Fields terminated by '\t' trailing nullcols
(
  FUNDER_ID,
  YEAR,
  WORKS_COUNT,
  CITED_BY_COUNT
)