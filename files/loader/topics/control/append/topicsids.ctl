load data 
characterset utf8
infile '.\csv\topicsids.csv'
BADFILE '.\logs\topicsids.bad'
DISCARDFILE '.\logs\topicsids.dsc'
append into table openalex.topics_ids
Fields terminated by '\t' trailing nullcols
(
  TOPIC_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  WIKIPEDIA
)