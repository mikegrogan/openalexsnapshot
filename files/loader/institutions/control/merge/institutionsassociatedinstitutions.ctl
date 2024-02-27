load data 
characterset utf8
infile '.\csv\institutionsassociatedinstitutions.csv'
BADFILE '.\logs\institutionsassociatedinstitutions.bad'
DISCARDFILE '.\logs\institutionsassociatedinstitutions.dsc'
truncate into table openalex.stage$institutions_associated_institutions
Fields terminated by '\t' trailing nullcols
(
  INSTITUTION_ID,
  ASSOCIATED_INSTITUTION_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  RELATIONSHIP
)