load data 
characterset utf8
infile '.\csv\topicssiblings.csv'
BADFILE '.\logs\topicssiblings.bad'
DISCARDFILE '.\logs\topicssiblings.dsc'
truncate into table openalex.stage$topics_siblings
Fields terminated by '\t' trailing nullcols
(
  TOPIC_ID,
  SIBLING_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER
)