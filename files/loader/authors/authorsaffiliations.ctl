load data 
characterset utf8
infile '.\csv\authorsaffiliations.csv'
BADFILE '.\logs\authorsaffiliations.bad'
DISCARDFILE '.\logs\authorsaffiliations.dsc'
truncate into table openalex.stage$authors_affiliations
Fields terminated by '\t' trailing nullcols
(
  AUTHOR_ID,
  INSTITUTION_ID,
  YEAR
)