load data 
characterset utf8
infile '.\csv\institutionscountsbyyear.csv'
BADFILE '.\logs\institutionscountsbyyear.bad'
DISCARDFILE '.\logs\institutionscountsbyyear.dsc'
truncate into table openalex.stage$institutions_counts_by_year
Fields terminated by '\t' trailing nullcols
(
  INSTITUTION_ID,
  YEAR,
  WORKS_COUNT,
  CITED_BY_COUNT,
  OA_WORKS_COUNT
)