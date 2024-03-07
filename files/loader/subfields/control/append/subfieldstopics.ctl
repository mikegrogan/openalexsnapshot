load data 
characterset utf8
infile '.\csv\subfieldstopics.csv'
BADFILE '.\logs\subfieldstopics.bad'
DISCARDFILE '.\logs\subfieldstopics.dsc'
append into table openalex.subfields_topics
Fields terminated by '\t' trailing nullcols
(
  SUBFIELD_ID,
  TOPIC_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)