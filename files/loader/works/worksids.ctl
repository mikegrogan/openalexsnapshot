load data 
characterset utf8
infile '.\csv\worksids.csv'
BADFILE '.\logs\worksids.bad'
DISCARDFILE '.\logs\worksids.dsc'
truncate into table openalex.stage$works_IDS
Fields terminated by '\t' trailing nullcols
(
  WORK_ID,
  OPENALEX,
  DOI,
  MAG,
  PMID,
  PMCID
)