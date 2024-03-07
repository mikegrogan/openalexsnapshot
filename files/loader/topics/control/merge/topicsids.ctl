load data 
characterset utf8
infile '.\csv\topicsids.csv'
BADFILE '.\logs\topicsids.bad'
DISCARDFILE '.\logs\topicsids.dsc'
truncate into table openalex.stage$topics_ids
Fields terminated by '\t' trailing nullcols
(
  TOPIC_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  WIKIPEDIA
)