load data 
characterset utf8
infile '.\csv\workstopics.csv'
BADFILE '.\logs\workstopics.bad'
DISCARDFILE '.\logs\workstopics.dsc'
append into table openalex.works_topics
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  TOPIC_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  SCORE,
  SUBFIELD_ID,
  FIELD_ID,
  DOMAIN_ID
)