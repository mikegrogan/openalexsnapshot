-- based off of https://github.com/ourresearch/openalex-documentation-scripts/blob/main/openalex-pg-schema.sql
-- drop statement will error if tables aren't present
DROP TABLE openalex.stage$authors cascade constraints;
DROP TABLE openalex.stage$authors_affiliations cascade constraints;
DROP TABLE openalex.stage$authors_counts_by_year cascade constraints;
DROP TABLE openalex.stage$authors_ids cascade constraints;
DROP TABLE openalex.stage$concepts cascade constraints;
DROP TABLE openalex.stage$concepts_ancestors cascade constraints;
DROP TABLE openalex.stage$concepts_counts_by_year cascade constraints;
DROP TABLE openalex.stage$concepts_ids cascade constraints;
DROP TABLE openalex.stage$concepts_related_concepts cascade constraints;
DROP TABLE openalex.stage$funders cascade constraints;
DROP TABLE openalex.stage$funders_ids cascade constraints;
DROP TABLE openalex.stage$funders_counts_by_year cascade constraints;
DROP TABLE openalex.stage$institutions cascade constraints;
DROP TABLE openalex.stage$institutions_associated_institutions cascade constraints;
DROP TABLE openalex.stage$institutions_counts_by_year cascade constraints;
DROP TABLE openalex.stage$institutions_geo cascade constraints;
DROP TABLE openalex.stage$institutions_ids cascade constraints;
DROP TABLE openalex.stage$publishers cascade constraints;
DROP TABLE openalex.stage$publishers_counts_by_year cascade constraints;
DROP TABLE openalex.stage$publishers_ids cascade constraints;
DROP TABLE openalex.stage$sources cascade constraints;
DROP TABLE openalex.stage$sources_counts_by_year cascade constraints;
DROP TABLE openalex.stage$sources_ids cascade constraints;
DROP TABLE openalex.stage$works cascade constraints;
DROP TABLE openalex.stage$works_primary_locations cascade constraints;
DROP TABLE openalex.stage$works_locations cascade constraints;
DROP TABLE openalex.stage$works_best_oa_locations cascade constraints;
DROP TABLE openalex.stage$works_authorships cascade constraints;
DROP TABLE openalex.stage$works_biblio cascade constraints;
DROP TABLE openalex.stage$works_concepts cascade constraints;
DROP TABLE openalex.stage$works_ids cascade constraints;
DROP TABLE openalex.stage$works_mesh cascade constraints;
DROP TABLE openalex.stage$works_open_access cascade constraints;
DROP TABLE openalex.stage$works_referenced_works cascade constraints;
DROP TABLE openalex.stage$works_related_works cascade constraints;
DROP TABLE openalex.stage$works_topics cascade constraints;
DROP TABLE openalex.stage$domains cascade constraints;
DROP TABLE openalex.stage$domains_fields cascade constraints;
DROP TABLE openalex.stage$domains_ids cascade constraints;
DROP TABLE openalex.stage$domains_siblings cascade constraints;
DROP TABLE openalex.stage$fields cascade constraints;
DROP TABLE openalex.stage$fields_ids cascade constraints;
DROP TABLE openalex.stage$fields_siblings cascade constraints;
DROP TABLE openalex.stage$fields_subfields cascade constraints;
DROP TABLE openalex.stage$subfields cascade constraints;
DROP TABLE openalex.stage$subfields_ids cascade constraints;
DROP TABLE openalex.stage$subfields_siblings cascade constraints;
DROP TABLE openalex.stage$subfields_topics cascade constraints;
DROP TABLE openalex.stage$topics cascade constraints;
DROP TABLE openalex.stage$topics_ids cascade constraints;
DROP TABLE openalex.stage$topics_siblings cascade constraints;

DROP TABLE openalex.stage$mergeids cascade constraints;

DROP TABLE openalex.authors cascade constraints;
DROP TABLE openalex.authors_affiliations cascade constraints;
DROP TABLE openalex.authors_counts_by_year cascade constraints;
DROP TABLE openalex.authors_ids cascade constraints;
DROP TABLE openalex.concepts cascade constraints;
DROP TABLE openalex.concepts_ancestors cascade constraints;
DROP TABLE openalex.concepts_counts_by_year cascade constraints;
DROP TABLE openalex.concepts_ids cascade constraints;
DROP TABLE openalex.concepts_related_concepts cascade constraints;
DROP TABLE openalex.funders cascade constraints;
DROP TABLE openalex.funders_ids cascade constraints;
DROP TABLE openalex.funders_counts_by_year cascade constraints;
DROP TABLE openalex.institutions cascade constraints;
DROP TABLE openalex.institutions_associated_institutions cascade constraints;
DROP TABLE openalex.institutions_counts_by_year cascade constraints;
DROP TABLE openalex.institutions_geo cascade constraints;
DROP TABLE openalex.institutions_ids cascade constraints;
DROP TABLE openalex.publishers cascade constraints;
DROP TABLE openalex.publishers_counts_by_year cascade constraints;
DROP TABLE openalex.publishers_ids cascade constraints;
DROP TABLE openalex.sources cascade constraints;
DROP TABLE openalex.sources_counts_by_year cascade constraints;
DROP TABLE openalex.sources_ids cascade constraints;
DROP TABLE openalex.works cascade constraints;
DROP TABLE openalex.works_primary_locations cascade constraints;
DROP TABLE openalex.works_locations cascade constraints;
DROP TABLE openalex.works_best_oa_locations cascade constraints;
DROP TABLE openalex.works_authorships cascade constraints;
DROP TABLE openalex.works_biblio cascade constraints;
DROP TABLE openalex.works_concepts cascade constraints;
DROP TABLE openalex.works_ids cascade constraints;
DROP TABLE openalex.works_mesh cascade constraints;
DROP TABLE openalex.works_open_access cascade constraints;
DROP TABLE openalex.works_referenced_works cascade constraints;
DROP TABLE openalex.works_related_works cascade constraints;
DROP TABLE openalex.works_topics cascade constraints;
DROP TABLE openalex.domains cascade constraints;
DROP TABLE openalex.domains_fields cascade constraints;
DROP TABLE openalex.domains_ids cascade constraints;
DROP TABLE openalex.domains_siblings cascade constraints;
DROP TABLE openalex.fields cascade constraints;
DROP TABLE openalex.fields_ids cascade constraints;
DROP TABLE openalex.fields_siblings cascade constraints;
DROP TABLE openalex.fields_subfields cascade constraints;
DROP TABLE openalex.subfields cascade constraints;
DROP TABLE openalex.subfields_ids cascade constraints;
DROP TABLE openalex.subfields_siblings cascade constraints;
DROP TABLE openalex.subfields_topics cascade constraints;
DROP TABLE openalex.topics cascade constraints;
DROP TABLE openalex.topics_ids cascade constraints;
DROP TABLE openalex.topics_siblings cascade constraints;

DROP TABLE openalex.entitylatestsync cascade constraints;
DROP TABLE openalex.entitymergelatestsync cascade constraints;

CREATE TABLE openalex.entitylatestsync (
    entity VARCHAR2(30),
    updateDate DATE,
    fileNumber NUMBER,
    filename VARCHAR2(30),
    fileurl VARCHAR2(255),
    totalfiles NUMBER,
    recordcount NUMBER,
    manifesthash VARCHAR2(50),
    createdat TIMESTAMP default CURRENT_TIMESTAMP,
    primary key (entity)
) COMPRESS FOR ALL OPERATIONS;
-- ) COMPRESS FOR ALL OPERATIONS;

CREATE TABLE openalex.entitymergelatestsync (
    entity VARCHAR2(30),
    updateDate DATE,
    filename VARCHAR2(30),
    fileurl VARCHAR2(255),
    createdat TIMESTAMP default CURRENT_TIMESTAMP,
    primary key (entity)
) COMPRESS FOR ALL OPERATIONS;

CREATE TABLE openalex.stage$mergeids (
    merge_date  date,
    id  VARCHAR2(50),
    merge_into_id VARCHAR2(50)
) COMPRESS FOR ALL OPERATIONS;

CREATE TABLE openalex.authors (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    orcid VARCHAR2(50),
    display_name NVARCHAR2(1000),
    display_name_alternatives NCLOB, --CHECK (display_name_alternatives IS JSON)
    works_count NUMBER,
    cited_by_count NUMBER,
    last_known_institution VARCHAR2(50),
    works_api_url VARCHAR2(200),
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.authors
ADD CONSTRAINT pk_authors PRIMARY KEY (id);

ALTER INDEX pk_authors REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.authors
-- MODIFY PARTITION BY HASH(id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$authors AS
SELECT * FROM OPENALEX.authors WHERE 1 = 0;

CREATE TABLE openalex.authors_affiliations (
    author_id VARCHAR2(50),
    institution_id VARCHAR2(50),
    year NUMBER,
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.authors_affiliations
ADD CONSTRAINT pk_authors_affiliations PRIMARY KEY (author_id,institution_id,year);

ALTER INDEX pk_authors_affiliations REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$authors_affiliations AS
SELECT * FROM OPENALEX.authors_affiliations WHERE 1 = 0;

CREATE TABLE openalex.authors_counts_by_year (
    author_id VARCHAR2(50),
    year NUMBER,
    snapshotdate date,
    snapshotfilenumber NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.authors_counts_by_year
ADD CONSTRAINT pk_authors_counts_by_year PRIMARY KEY (author_id,year);

ALTER INDEX pk_authors_counts_by_year REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$authors_counts_by_year AS
SELECT * FROM OPENALEX.authors_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.authors_ids (
    author_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    openalex VARCHAR2(50),
    orcid VARCHAR2(50),
    scopus VARCHAR2(200),
    twitter VARCHAR2(200),
    wikipedia VARCHAR2(3000),
    mag NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.authors_ids
ADD CONSTRAINT pk_authors_ids PRIMARY KEY (author_id);

ALTER INDEX pk_authors_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$authors_ids AS
SELECT * FROM OPENALEX.authors_ids WHERE 1 = 0;

-- https://docs.google.com/document/d/1OgXSLriHO3Ekz0OYoaoP_h0sPcuvV4EqX7VgLLblKe4/edit#heading=h.mwc8rq67dbn1

CREATE TABLE openalex.concepts (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    wikidata VARCHAR2(50),
    display_name NVARCHAR2(1000),
    concept_level NUMBER,
    description NVARCHAR2(500),
    works_count NUMBER,
    cited_by_count NUMBER,
    image_url VARCHAR2(1000),
    image_thumbnail_url VARCHAR2(1000),
    works_api_url VARCHAR2(200),
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.concepts
ADD CONSTRAINT pk_concepts PRIMARY KEY (id);

ALTER INDEX pk_concepts REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$concepts AS
SELECT * FROM OPENALEX.concepts WHERE 1 = 0;

CREATE TABLE openalex.concepts_ancestors (
    concept_id VARCHAR2(50),
    ancestor_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.concepts_ancestors
ADD CONSTRAINT pk_concepts_ancestors PRIMARY KEY (concept_id,ancestor_id);

ALTER INDEX pk_concepts_ancestors REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$concepts_ancestors AS
SELECT * FROM OPENALEX.concepts_ancestors WHERE 1 = 0;

CREATE TABLE openalex.concepts_counts_by_year (
    concept_id VARCHAR2(50),
    year NUMBER,
    snapshotdate date,
    snapshotfilenumber NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.concepts_counts_by_year
ADD CONSTRAINT pk_concepts_counts_by_year PRIMARY KEY (concept_id,year);

ALTER INDEX pk_concepts_counts_by_year REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$concepts_counts_by_year AS
SELECT * FROM OPENALEX.concepts_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.concepts_ids (
    concept_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    openalex VARCHAR2(50),
    wikidata VARCHAR2(50),
    wikipedia VARCHAR2(3000),
    umls_aui CLOB, --CHECK (umls_aui IS JSON)
    umls_cui CLOB, --CHECK (umls_cui IS JSON)
    mag NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.concepts_ids
ADD CONSTRAINT pk_concepts_ids PRIMARY KEY (concept_id);

ALTER INDEX pk_concepts_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$concepts_ids AS
SELECT * FROM OPENALEX.concepts_ids WHERE 1 = 0;

CREATE TABLE openalex.concepts_related_concepts (
    concept_id VARCHAR2(255),
    related_concept_id VARCHAR2(255),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    score NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.concepts_related_concepts
ADD CONSTRAINT pk_concepts_related_concepts PRIMARY KEY (concept_id,related_concept_id);

ALTER INDEX pk_concepts_related_concepts REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$concepts_related_concepts AS
SELECT * FROM OPENALEX.concepts_related_concepts WHERE 1 = 0;


CREATE TABLE openalex.funders (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    display_name NVARCHAR2(1500),
    alternate_titles NCLOB, --CHECK (alternate_titles IS JSON)
    country_code VARCHAR2(50),
    description NVARCHAR2(500),
    homepage_url VARCHAR2(1000),
    image_url VARCHAR2(1000),
    image_thumbnail_url VARCHAR2(1000),
    grants_count NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.funders
ADD CONSTRAINT pk_funders PRIMARY KEY (id);

ALTER INDEX pk_funders REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$funders AS
SELECT * FROM OPENALEX.funders WHERE 1 = 0;

CREATE TABLE openalex.funders_ids (
    funder_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    openalex VARCHAR2(50),
    ror VARCHAR2(50),
    wikidata VARCHAR2(50),
    crossref VARCHAR2(50),
    doi VARCHAR2(400)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.funders_ids
ADD CONSTRAINT pk_funders_ids PRIMARY KEY (funder_id);

ALTER INDEX pk_funders_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$funders_ids AS
SELECT * FROM OPENALEX.funders_ids WHERE 1 = 0;

CREATE TABLE openalex.funders_counts_by_year (
    funder_id VARCHAR2(50),
    year NUMBER,
    snapshotdate date,
    snapshotfilenumber NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.funders_counts_by_year
ADD CONSTRAINT pk_funders_counts_by_year PRIMARY KEY (funder_id,year);

ALTER INDEX pk_funders_counts_by_year REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$funders_counts_by_year AS
SELECT * FROM OPENALEX.funders_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.institutions (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    ror VARCHAR2(50),
    display_name NVARCHAR2(1000),
    country_code VARCHAR2(50),
    type VARCHAR2(50),
    homepage_url VARCHAR2(1000),
    image_url VARCHAR2(1000),
    image_thumbnail_url VARCHAR2(1000),
    display_name_acronyms CLOB, --CHECK (display_name_acronyms IS JSON)
    display_name_alternatives NCLOB, --CHECK (display_name_alternatives IS JSON)
    works_count NUMBER,
    cited_by_count NUMBER,
    works_api_url VARCHAR2(200),
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.institutions
ADD CONSTRAINT pk_institutions PRIMARY KEY (id);

ALTER INDEX pk_institutions REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$institutions AS
SELECT * FROM OPENALEX.institutions WHERE 1 = 0;

CREATE TABLE openalex.institutions_associated_institutions (
    institution_id VARCHAR2(50),
    associated_institution_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    relationship VARCHAR2(255)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.institutions_associated_institutions
ADD CONSTRAINT pk_institutions_associated_institutions PRIMARY KEY (institution_id,associated_institution_id);

ALTER INDEX pk_institutions_associated_institutions REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$institutions_associated_institutions AS
SELECT * FROM OPENALEX.institutions_associated_institutions WHERE 1 = 0;

CREATE TABLE openalex.institutions_counts_by_year (
    institution_id VARCHAR2(50),
    year NUMBER,
    snapshotdate date,
    snapshotfilenumber NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.institutions_counts_by_year
ADD CONSTRAINT pk_institutions_counts_by_year PRIMARY KEY (institution_id,year);

ALTER INDEX pk_institutions_counts_by_year REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$institutions_counts_by_year AS
SELECT * FROM OPENALEX.institutions_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.institutions_geo (
    institution_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    city VARCHAR2(500),
    geonames_city_id VARCHAR2(50),
    region VARCHAR2(50),
    country_code VARCHAR2(10),
    country VARCHAR2(100),
    latitude NUMBER,
    longitude NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.institutions_geo
ADD CONSTRAINT pk_institutions_geo PRIMARY KEY (institution_id);

ALTER INDEX pk_institutions_geo REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$institutions_geo AS
SELECT * FROM OPENALEX.institutions_geo WHERE 1 = 0;

CREATE TABLE openalex.institutions_ids (
    institution_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    openalex VARCHAR2(50),
    ror VARCHAR2(50),
    grid VARCHAR2(50),
    wikipedia VARCHAR2(3000),
    wikidata VARCHAR2(50),
    mag NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.institutions_ids
ADD CONSTRAINT pk_institutions_ids PRIMARY KEY (institution_id);

ALTER INDEX pk_institutions_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$institutions_ids AS
SELECT * FROM OPENALEX.institutions_ids WHERE 1 = 0;

CREATE TABLE openalex.publishers (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    display_name NVARCHAR2(1000),
    alternate_titles NCLOB, --CHECK (alternate_titles IS JSON)
    country_codes CLOB, --CHECK (country_codes IS JSON)
    hierarchy_level NUMBER,
    parent_publisher VARCHAR2(50),
    homepage_url VARCHAR2(1000),
    image_url VARCHAR2(1000),
    image_thumbnail_url VARCHAR2(1000),
    works_count NUMBER,
    cited_by_count NUMBER,
    sources_api_url VARCHAR2(200),
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.publishers
ADD CONSTRAINT pk_publishers PRIMARY KEY (id);

ALTER INDEX pk_publishers REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$publishers AS
SELECT * FROM OPENALEX.publishers WHERE 1 = 0;

CREATE TABLE openalex.publishers_counts_by_year (
    publisher_id VARCHAR2(50),
    year NUMBER,
    snapshotdate date,
    snapshotfilenumber NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.publishers_counts_by_year
ADD CONSTRAINT pk_publishers_counts_by_year PRIMARY KEY (publisher_id,year);

ALTER INDEX pk_publishers_counts_by_year REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$publishers_counts_by_year AS
SELECT * FROM OPENALEX.publishers_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.publishers_ids (
    publisher_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    openalex VARCHAR2(50),
    ror VARCHAR2(50),
    wikidata VARCHAR2(50)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.publishers_ids
ADD CONSTRAINT pk_publishers_ids PRIMARY KEY (publisher_id);

ALTER INDEX pk_publishers_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$publishers_ids AS
SELECT * FROM OPENALEX.publishers_ids WHERE 1 = 0;

CREATE TABLE openalex.sources (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    issn_l VARCHAR2(50),
    issn CLOB, --CHECK (issn IS JSON)
    display_name NVARCHAR2(1500),
    publisher VARCHAR2(50),
    works_count NUMBER,
    cited_by_count NUMBER,
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    is_in_doaj NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    homepage_url VARCHAR2(1000),
    works_api_url VARCHAR2(1000),
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.sources
ADD CONSTRAINT pk_sources PRIMARY KEY (id);

ALTER INDEX pk_sources REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$sources AS
SELECT * FROM OPENALEX.sources WHERE 1 = 0;

CREATE TABLE openalex.sources_counts_by_year (
    source_id VARCHAR2(50),
    year NUMBER,
    snapshotdate date,
    snapshotfilenumber NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.sources_counts_by_year
ADD CONSTRAINT pk_sources_counts_by_year PRIMARY KEY (source_id,year);

ALTER INDEX pk_sources_counts_by_year REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$sources_counts_by_year AS
SELECT * FROM OPENALEX.sources_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.sources_ids (
    source_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    openalex VARCHAR2(50),
    issn_l VARCHAR2(50),
    issn CLOB, --CHECK (issn IS JSON)
    mag NUMBER,
    wikidata VARCHAR2(50),
    fatcat VARCHAR2(100)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.sources_ids
ADD CONSTRAINT pk_sources_ids PRIMARY KEY (source_id);

ALTER INDEX pk_sources_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$sources_ids AS
SELECT * FROM OPENALEX.sources_ids WHERE 1 = 0;

-- https://docs.google.com/document/d/1bDopkhuGieQ4F8gGNj7sEc8WSE8mvLZS/edit#heading=h.5w2tb5fcg77r

CREATE TABLE openalex.topics (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    display_name NVARCHAR2(1000),
    description NVARCHAR2(1000),
    keywords NCLOB,
    subfield_id VARCHAR2(50),
    field_id VARCHAR2(50),
    domain_id VARCHAR2(50),
    works_count NUMBER,
    cited_by_count NUMBER,
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.topics
ADD CONSTRAINT pk_topics PRIMARY KEY (id);

ALTER INDEX pk_topics REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$topics AS
SELECT * FROM OPENALEX.topics WHERE 1 = 0;

CREATE TABLE openalex.topics_ids (
    topic_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    openalex VARCHAR2(50),
    wikipedia VARCHAR2(3000)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.topics_ids
ADD CONSTRAINT pk_topics_ids PRIMARY KEY (topic_id);

ALTER INDEX pk_topics_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$topics_ids AS
SELECT * FROM OPENALEX.topics_ids WHERE 1 = 0;

CREATE TABLE openalex.topics_siblings (
    topic_id VARCHAR2(50),
    sibling_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.topics_siblings
ADD CONSTRAINT pk_topics_siblings PRIMARY KEY (topic_id,sibling_id);

ALTER INDEX pk_topics_siblings REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$topics_siblings AS
SELECT * FROM OPENALEX.topics_siblings WHERE 1 = 0;

CREATE TABLE openalex.subfields (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    display_name NVARCHAR2(1000),
    display_name_alternatives NCLOB,
    description NVARCHAR2(500),
    field_id VARCHAR2(50),
    domain_id VARCHAR2(50),
    works_count NUMBER,
    cited_by_count NUMBER,
    works_api_url VARCHAR2(200),
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.subfields
ADD CONSTRAINT pk_subfields PRIMARY KEY (id);

ALTER INDEX pk_subfields REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$subfields AS
SELECT * FROM OPENALEX.subfields WHERE 1 = 0;

CREATE TABLE openalex.subfields_ids (
    subfield_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    wikidata VARCHAR2(3000),
    wikipedia VARCHAR2(3000)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.subfields_ids
ADD CONSTRAINT pk_subfields_ids PRIMARY KEY (subfield_id);

ALTER INDEX pk_subfields_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$subfields_ids AS
SELECT * FROM OPENALEX.subfields_ids WHERE 1 = 0;

CREATE TABLE openalex.subfields_topics (
    subfield_id VARCHAR2(50),
    topic_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.subfields_topics
ADD CONSTRAINT pk_subfields_topics PRIMARY KEY (subfield_id,topic_id);

ALTER INDEX pk_subfields_topics REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$subfields_topics AS
SELECT * FROM OPENALEX.subfields_topics WHERE 1 = 0;

CREATE TABLE openalex.subfields_siblings (
    subfield_id VARCHAR2(50),
    sibling_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.subfields_siblings
ADD CONSTRAINT pk_subfields_siblings PRIMARY KEY (subfield_id,sibling_id);

ALTER INDEX pk_subfields_siblings REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$subfields_siblings AS
SELECT * FROM OPENALEX.subfields_siblings WHERE 1 = 0;

CREATE TABLE openalex.fields (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    display_name NVARCHAR2(1000),
    display_name_alternatives NCLOB,
    description NVARCHAR2(1000),
    domain_id VARCHAR2(50),
    works_count NUMBER,
    cited_by_count NUMBER,
    works_api_url VARCHAR2(200),
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.fields
ADD CONSTRAINT pk_fields PRIMARY KEY (id);

ALTER INDEX pk_fields REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$fields AS
SELECT * FROM OPENALEX.fields WHERE 1 = 0;

CREATE TABLE openalex.fields_ids (
    field_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    wikidata VARCHAR2(3000),
    wikipedia VARCHAR2(3000)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.fields_ids
ADD CONSTRAINT pk_fields_ids PRIMARY KEY (field_id);

ALTER INDEX pk_fields_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$fields_ids AS
SELECT * FROM OPENALEX.fields_ids WHERE 1 = 0;

CREATE TABLE openalex.fields_subfields (
    field_id VARCHAR2(50),
    subfield_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.fields_subfields
ADD CONSTRAINT pk_fields_subfields PRIMARY KEY (field_id,subfield_id);

ALTER INDEX pk_fields_subfields REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$fields_subfields AS
SELECT * FROM OPENALEX.fields_subfields WHERE 1 = 0;

CREATE TABLE openalex.fields_siblings (
    field_id VARCHAR2(50),
    sibling_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.fields_siblings
ADD CONSTRAINT pk_fields_siblings PRIMARY KEY (field_id,sibling_id);

ALTER INDEX pk_fields_siblings REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$fields_siblings AS
SELECT * FROM OPENALEX.fields_siblings WHERE 1 = 0;

CREATE TABLE openalex.domains (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    display_name NVARCHAR2(1000),
    display_name_alternatives NCLOB,
    description NVARCHAR2(500),
    works_count NUMBER,
    cited_by_count NUMBER,
    works_api_url VARCHAR2(200),
    updated_date TIMESTAMP
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.domains
ADD CONSTRAINT pk_domains PRIMARY KEY (id);

ALTER INDEX pk_domains REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$domains AS
SELECT * FROM OPENALEX.domains WHERE 1 = 0;

CREATE TABLE openalex.domains_ids (
    domain_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    wikidata VARCHAR2(3000),
    wikipedia VARCHAR2(3000)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.domains_ids
ADD CONSTRAINT pk_domains_ids PRIMARY KEY (domain_id);

ALTER INDEX pk_domains_ids REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$domains_ids AS
SELECT * FROM OPENALEX.domains_ids WHERE 1 = 0;

CREATE TABLE openalex.domains_fields (
    domain_id VARCHAR2(50),
    field_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.domains_fields
ADD CONSTRAINT pk_domains_fields PRIMARY KEY (domain_id,field_id);

ALTER INDEX pk_domains_fields REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$domains_fields AS
SELECT * FROM OPENALEX.domains_fields WHERE 1 = 0;

CREATE TABLE openalex.domains_siblings (
    domain_id VARCHAR2(50),
    sibling_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.domains_siblings
ADD CONSTRAINT pk_domains_siblings PRIMARY KEY (domain_id,sibling_id);

ALTER INDEX pk_domains_siblings REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$domains_siblings AS
SELECT * FROM OPENALEX.domains_siblings WHERE 1 = 0;

CREATE TABLE openalex.works (
    id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    doi VARCHAR2(400),
    title NVARCHAR2(1500),
    display_name NVARCHAR2(1500),
    publication_year NUMBER,
    publication_date DATE,
    type VARCHAR2(50),
    cited_by_count NUMBER,
    is_retracted NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    is_paratext NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    cited_by_api_url VARCHAR2(200),
    language VARCHAR2(50)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works
ADD CONSTRAINT pk_works PRIMARY KEY (id);

ALTER INDEX pk_works REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$works AS
SELECT * FROM OPENALEX.works WHERE 1 = 0;

-- ALTER TABLE openalex.works
-- MODIFY PARTITION BY HASH(id) PARTITIONS 8;

-- unfortunately source_id can be blank, as well as landing_page_url or pdf_url
-- so creating a unique_id to make it simpler
CREATE TABLE openalex.works_primary_locations (
    unique_id VARCHAR2(40),
    work_id VARCHAR2(50),
    source_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    landing_page_url VARCHAR2(2000),
    pdf_url VARCHAR2(4000),
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    version VARCHAR2(50),
    license VARCHAR2(50)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_primary_locations
ADD CONSTRAINT pk_works_primary_locations PRIMARY KEY (unique_id);

ALTER INDEX pk_works_primary_locations REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_primary_locations
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_primary_locations AS
SELECT * FROM OPENALEX.works_primary_locations WHERE 1 = 0;

-- unfortunately source_id can be blank, as well as landing_page_url or pdf_url
-- so creating a unique_id to make it simpler
CREATE TABLE openalex.works_locations (
    unique_id VARCHAR2(40),
    work_id VARCHAR2(50),
    source_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    landing_page_url VARCHAR2(2000),
    pdf_url VARCHAR2(4000),
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    version VARCHAR2(50),
    license VARCHAR2(50)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_locations
ADD CONSTRAINT pk_works_locations PRIMARY KEY (unique_id);

ALTER INDEX pk_works_locations REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_locations
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_locations AS
SELECT * FROM OPENALEX.works_locations WHERE 1 = 0;

-- unfortunately source_id can be blank, as well as landing_page_url or pdf_url. 
-- if all 3 are blank, then there is no best_oa_location
-- so creating a unique_id to make it simpler
CREATE TABLE openalex.works_best_oa_locations (
    unique_id VARCHAR2(40),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    work_id VARCHAR2(50),
    source_id VARCHAR2(50),
    landing_page_url VARCHAR2(2000),
    pdf_url VARCHAR2(4000),
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    version VARCHAR2(50),
    license VARCHAR2(50)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_best_oa_locations
ADD CONSTRAINT pk_works_best_oa_locations PRIMARY KEY (unique_id);

ALTER INDEX pk_works_best_oa_locations REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_best_oa_locations
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_best_oa_locations AS
SELECT * FROM OPENALEX.works_best_oa_locations WHERE 1 = 0;

-- ALTER TABLE openalex.stage$works_best_oa_locations
-- DROP COLUMN UNIQUE_ID;


CREATE TABLE openalex.works_authorships (
    unique_id VARCHAR2(40),
    work_id VARCHAR2(50),
    author_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    author_position VARCHAR2(50),
    raw_author_name NCLOB,
    institution_id VARCHAR2(50),
    raw_affiliation_string NCLOB
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_authorships
ADD CONSTRAINT pk_works_authorships PRIMARY KEY (unique_id);

ALTER INDEX pk_works_authorships REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_authorships
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_authorships AS
SELECT * FROM OPENALEX.works_authorships WHERE 1 = 0;

CREATE TABLE openalex.works_biblio (
    work_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    volume VARCHAR2(50),
    issue VARCHAR2(100),
    first_page VARCHAR2(100),
    last_page VARCHAR2(100)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_biblio
ADD CONSTRAINT pk_works_biblio PRIMARY KEY (work_id);

ALTER INDEX pk_works_biblio REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_biblio
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_biblio AS
SELECT * FROM OPENALEX.works_biblio WHERE 1 = 0;

CREATE TABLE openalex.works_concepts (
    work_id VARCHAR2(50),
    concept_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    score NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_concepts
ADD CONSTRAINT pk_works_concepts PRIMARY KEY (work_id,concept_id);

ALTER INDEX pk_works_concepts REBUILD NOLOGGING PARALLEL 8;

CREATE TABLE OPENALEX.stage$works_concepts AS
SELECT * FROM OPENALEX.works_concepts WHERE 1 = 0;


-- ALTER TABLE openalex.works_concepts
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE openalex.works_ids (
    work_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    openalex VARCHAR2(50),
    doi VARCHAR2(400),
    mag NUMBER,
    pmid VARCHAR2(100),
    pmcid VARCHAR2(100)
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_ids
ADD CONSTRAINT pk_works_ids PRIMARY KEY (work_id);

ALTER INDEX pk_works_ids REBUILD NOLOGGING PARALLEL 8;


CREATE TABLE OPENALEX.stage$works_ids AS
SELECT * FROM OPENALEX.works_ids WHERE 1 = 0;

CREATE TABLE openalex.works_mesh (
    work_id VARCHAR2(50),
    merge_id VARCHAR2(100),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    descriptor_ui VARCHAR2(50),
    descriptor_name VARCHAR2(150),
    qualifier_ui VARCHAR2(50),
    qualifier_name VARCHAR2(100),
    is_major_topic NUMBER(1,0)  -- Assuming 1 or 0 for boolean values
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_mesh
ADD CONSTRAINT pk_works_mesh PRIMARY KEY (work_id,merge_id);

ALTER INDEX pk_works_mesh REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_mesh
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_mesh AS
SELECT * FROM OPENALEX.works_mesh WHERE 1 = 0;

CREATE TABLE openalex.works_open_access (
    work_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    oa_status VARCHAR2(50),
    oa_url VARCHAR2(4000),
    any_repository_has_fulltext NUMBER(1,0)  -- Assuming 1 or 0 for boolean values
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_open_access
ADD CONSTRAINT pk_works_open_access PRIMARY KEY (work_id);

ALTER INDEX pk_works_open_access REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_open_access
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_open_access AS
SELECT * FROM OPENALEX.works_open_access WHERE 1 = 0;

CREATE TABLE openalex.works_referenced_works (
    work_id VARCHAR2(50),
    referenced_work_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_referenced_works
ADD CONSTRAINT pk_works_referenced_works PRIMARY KEY (work_id,referenced_work_id);

ALTER INDEX pk_works_referenced_works REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_referenced_works
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_referenced_works AS
SELECT * FROM OPENALEX.works_referenced_works WHERE 1 = 0;

CREATE TABLE openalex.works_related_works (
    work_id VARCHAR2(50),
    related_work_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER
) COMPRESS FOR ALL OPERATIONS;

ALTER TABLE openalex.works_related_works
ADD CONSTRAINT pk_works_related_works PRIMARY KEY (work_id,related_work_id);

ALTER INDEX pk_works_related_works REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_related_works
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_related_works AS
SELECT * FROM OPENALEX.works_related_works WHERE 1 = 0;

CREATE TABLE openalex.works_topics (
    work_id VARCHAR2(50),
    topic_id VARCHAR2(50),
    snapshotdate date,
    snapshotfilenumber NUMBER,
    score NUMBER,
    subfield_id VARCHAR2(50),
    field_id VARCHAR2(50),
    domain_id VARCHAR2(50)
) COMPRESS FOR ALL OPERATIONS;

--ALTER TABLE openalex.works_topics COMPRESS FOR ALL OPERATIONS
ALTER TABLE openalex.works_topics
ADD CONSTRAINT pk_works_topics PRIMARY KEY (work_id,topic_id);

ALTER INDEX pk_works_topics REBUILD NOLOGGING PARALLEL 8;

-- ALTER TABLE openalex.works_related_works
-- MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_topics AS
SELECT * FROM OPENALEX.works_topics WHERE 1 = 0;