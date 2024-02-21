load data 
characterset utf8
infile '.\csv\worksreferencedworks.csv'
BADFILE '.\logs\worksreferencedworks.bad'
DISCARDFILE '.\logs\worksreferencedworks.dsc'
truncate into table openalex.stage$works_referenced_works
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  REFERENCED_WORK_ID
)