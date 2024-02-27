load data 
characterset utf8
infile '.\csv\conceptsrelatedconcepts.csv'
BADFILE '.\logs\conceptsrelatedconcepts.bad'
DISCARDFILE '.\logs\conceptsrelatedconcepts.dsc'
append into table openalex.concepts_related_concepts
Fields terminated by '\t' trailing nullcols
(
  CONCEPT_ID,
  RELATED_CONCEPT_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  SCORE
)