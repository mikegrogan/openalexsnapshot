load data 
characterset utf8
infile '.\csv\authorsconcepts.csv'
BADFILE '.\logs\authorsconcepts.bad'
DISCARDFILE '.\logs\authorsconcepts.dsc'
truncate into table openalex.stage$authors_concepts
Fields terminated by '\t' trailing nullcols
(
  AUTHOR_ID,
  CONCEPT_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  SCORE
)