load data 
characterset utf8
infile '.\csv\mergeids.csv'
BADFILE '.\logs\mergeids.bad'
DISCARDFILE '.\logs\mergeids.dsc'
truncate into table openalex.stage$mergeids
Fields terminated by ',' trailing nullcols
(
  MERGE_DATE DATE 'YYYY-MM-DD',
  ID,
  MERGE_INTO_ID
)