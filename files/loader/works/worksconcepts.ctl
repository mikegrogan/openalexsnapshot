load data 
characterset utf8
infile '.\csv\worksconcepts.csv'
BADFILE '.\logs\worksconcepts.bad'
DISCARDFILE '.\logs\worksconcepts.dsc'
truncate into table openalex.stage$works_concepts
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  CONCEPT_ID,
  SCORE
)