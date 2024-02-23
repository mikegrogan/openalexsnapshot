load data 
characterset utf8
infile '.\csv\worksids.csv'
BADFILE '.\logs\worksids.bad'
DISCARDFILE '.\logs\worksids.dsc'
append into table openalex.works_ids
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  OPENALEX,
  DOI CHAR(400),
  MAG,
  PMID,
  PMCID
)