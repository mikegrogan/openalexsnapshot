load data 
characterset utf8
infile '.\csv\institutionsgeo.csv'
BADFILE '.\logs\institutionsgeo.bad'
DISCARDFILE '.\logs\institutionsgeo.dsc'
append into table openalex.institutions_geo
Fields terminated by '\t' trailing nullcols
(
  INSTITUTION_ID,
  SNAPSHOTDATE Date "YYYY-MM-DD",
  SNAPSHOTFILENUMBER,
  CITY,
  GEONAMES_CITY_ID,
  REGION,
  COUNTRY_CODE,
  COUNTRY,
  LATITUDE,
  LONGITUDE
)