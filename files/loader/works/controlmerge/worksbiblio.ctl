load data 
characterset utf8
infile '.\csv\worksbiblio.csv'
BADFILE '.\logs\worksbiblio.bad'
DISCARDFILE '.\logs\worksbiblio.dsc'
truncate into table openalex.stage$works_biblio
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  VOLUME,
  ISSUE,
  FIRST_PAGE,
  LAST_PAGE
)