load data 
characterset utf8
infile '.\csv\conceptscountsbyyear.csv'
BADFILE '.\logs\conceptscountsbyyear.bad'
DISCARDFILE '.\logs\conceptscountsbyyear.dsc'
truncate into table openalex.stage$concepts_counts_by_year
Fields terminated by '\t' trailing nullcols
(
  CONCEPT_ID,
  YEAR,
  WORKS_COUNT,
  CITED_BY_COUNT,
  OA_WORKS_COUNT
)