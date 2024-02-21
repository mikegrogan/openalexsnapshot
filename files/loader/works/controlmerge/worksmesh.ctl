load data 
characterset utf8
infile '.\csv\worksmesh.csv'
BADFILE '.\logs\worksmesh.bad'
DISCARDFILE '.\logs\worksmesh.dsc'
truncate into table openalex.stage$works_mesh
Fields terminated by '\t' trailing nullcols
(
  MERGE_ID,
  WORK_ID,
  DESCRIPTOR_UI,
  DESCRIPTOR_NAME,
  QUALIFIER_UI,
  QUALIFIER_NAME,
  IS_MAJOR_TOPIC
)