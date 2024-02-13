load data 
characterset utf8
infile '.\csv\institutionsgeo.csv'
BADFILE '.\logs\institutionsgeo.bad'
DISCARDFILE '.\logs\institutionsgeo.dsc'
truncate into table openalex.stage$institutions_geo
Fields terminated by '\t' trailing nullcols
(
  INSTITUTION_ID,
  CITY,
  GEONAMES_CITY_ID,
  REGION,
  COUNTRY_CODE,
  COUNTRY,
  LATITUDE,
  LONGITUDE
)