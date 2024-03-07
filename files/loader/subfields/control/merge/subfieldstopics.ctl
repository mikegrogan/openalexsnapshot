load data 
characterset utf8
infile '.\csv\subfieldstopics.csv'
BADFILE '.\logs\subfieldstopics.bad'
DISCARDFILE '.\logs\subfieldstopics.dsc'
truncate into table openalex.stage$subfields_topics
Fields terminated by '\t' trailing nullcols
(
  SUBFIELD_ID,
  TOPIC_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)