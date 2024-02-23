load data 
characterset utf8
infile '.\csv\worksmesh.csv'
BADFILE '.\logs\worksmesh.bad'
DISCARDFILE '.\logs\worksmesh.dsc'
truncate into table openalex.stage$works_mesh
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  MERGE_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  DESCRIPTOR_UI,
  DESCRIPTOR_NAME,
  QUALIFIER_UI,
  QUALIFIER_NAME,
  IS_MAJOR_TOPIC
)