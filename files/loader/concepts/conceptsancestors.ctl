load data 
characterset utf8
infile '.\csv\conceptsancestors.csv'
BADFILE '.\logs\conceptsancestors.bad'
DISCARDFILE '.\logs\conceptsancestors.dsc'
truncate into table openalex.stage$concepts_ancestors
Fields terminated by '\t' trailing nullcols
(
  CONCEPT_ID,
  ANCESTOR_ID
)