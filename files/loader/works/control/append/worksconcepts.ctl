load data 
characterset utf8
infile '.\csv\worksconcepts.csv'
BADFILE '.\logs\worksconcepts.bad'
DISCARDFILE '.\logs\worksconcepts.dsc'
append into table openalex.works_concepts
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  CONCEPT_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  SCORE
)