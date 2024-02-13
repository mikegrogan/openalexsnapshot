-- based off of https://github.com/ourresearch/openalex-documentation-scripts/blob/main/openalex-pg-schema.sql
-- drop statement will error if tables aren't present
DROP TABLE openalex.authors cascade constraints;
DROP TABLE openalex.authors_counts_by_year cascade constraints;
DROP TABLE openalex.authors_ids cascade constraints;
DROP TABLE openalex.concepts cascade constraints;
DROP TABLE openalex.concepts_ancestors cascade constraints;
DROP TABLE openalex.concepts_counts_by_year cascade constraints;
DROP TABLE openalex.concepts_ids cascade constraints;
DROP TABLE openalex.concepts_related_concepts cascade constraints;
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
DROP TABLE openalex.entitysynclatest cascade constraints;

CREATE TABLE openalex.entitylatestsync (
    entity VARCHAR2(30),
    updateDate DATE,
    fileNumber NUMBER,
    filename VARCHAR2(30),
    fileurl VARCHAR2(255),
    totalfiles NUMBER,
    recordcount NUMBER,
    createdat TIMESTAMP default CURRENT_TIMESTAMP,
    primary key (entity)
);

CREATE TABLE openalex.entitymergelatestsync (
    entity VARCHAR2(30),
    updateDate DATE,
    filename VARCHAR2(30),
    fileurl VARCHAR2(255),
    createdat TIMESTAMP default CURRENT_TIMESTAMP,
    primary key (entity)
);

CREATE TABLE openalex.stage$mergeids (
    merge_date  date,
    id  VARCHAR2(50),
    merge_into_id VARCHAR2(50)
);

CREATE TABLE openalex.authors (
    id VARCHAR2(50) primary key,
    orcid VARCHAR2(50),
    display_name NVARCHAR2(1000),
    display_name_alternatives NCLOB CHECK (display_name_alternatives IS JSON),
    works_count NUMBER,
    cited_by_count NUMBER,
    last_known_institution VARCHAR2(50),
    works_api_url VARCHAR2(200),
    updated_date TIMESTAMP
);

ALTER TABLE openalex.authors
MODIFY PARTITION BY HASH(id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$authors AS
SELECT * FROM OPENALEX.authors WHERE 1 = 0;

CREATE TABLE openalex.authors_counts_by_year (
    author_id VARCHAR2(50),
    year NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER,
    primary key (author_id,year)
);

ALTER TABLE openalex.authors_counts_by_year
MODIFY PARTITION BY HASH(author_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$authors_counts_by_year AS
SELECT * FROM OPENALEX.authors_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.authors_ids (
    author_id VARCHAR2(50) primary key,
    openalex VARCHAR2(50),
    orcid VARCHAR2(50),
    scopus VARCHAR2(200),
    twitter VARCHAR2(200),
    wikipedia VARCHAR2(3000),
    mag NUMBER
);

ALTER TABLE openalex.authors_ids
MODIFY PARTITION BY HASH(author_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$authors_ids AS
SELECT * FROM OPENALEX.authors_ids WHERE 1 = 0;

-- https://docs.google.com/document/d/1OgXSLriHO3Ekz0OYoaoP_h0sPcuvV4EqX7VgLLblKe4/edit#heading=h.mwc8rq67dbn1

CREATE TABLE openalex.concepts (
    id VARCHAR2(50) primary key,
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
);

CREATE TABLE OPENALEX.stage$concepts AS
SELECT * FROM OPENALEX.concepts WHERE 1 = 0;

CREATE TABLE openalex.concepts_ancestors (
    concept_id VARCHAR2(50),
    ancestor_id VARCHAR2(50),
    primary key (concept_id,ancestor_id)
);

CREATE TABLE OPENALEX.stage$concepts_ancestors AS
SELECT * FROM OPENALEX.concepts_ancestors WHERE 1 = 0;

CREATE TABLE openalex.concepts_counts_by_year (
    concept_id VARCHAR2(50),
    year NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER,
    primary key (concept_id,year)
);

CREATE TABLE OPENALEX.stage$concepts_counts_by_year AS
SELECT * FROM OPENALEX.concepts_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.concepts_ids (
    concept_id VARCHAR2(50) primary key,
    openalex VARCHAR2(50),
    wikidata VARCHAR2(50),
    wikipedia VARCHAR2(3000),
    umls_aui CLOB CHECK (umls_aui IS JSON),
    umls_cui CLOB CHECK (umls_cui IS JSON),
    mag NUMBER
);

CREATE TABLE OPENALEX.stage$concepts_ids AS
SELECT * FROM OPENALEX.concepts_ids WHERE 1 = 0;

CREATE TABLE openalex.concepts_related_concepts (
    concept_id VARCHAR2(255),
    related_concept_id VARCHAR2(255),
    score NUMBER,
    primary key (concept_id,related_concept_id)
);

CREATE TABLE OPENALEX.stage$concepts_related_concepts AS
SELECT * FROM OPENALEX.concepts_related_concepts WHERE 1 = 0;


-- https://docs.google.com/document/d/1bDopkhuGieQ4F8gGNj7sEc8WSE8mvLZS/edit#heading=h.5w2tb5fcg77r

CREATE TABLE openalex.topics (
    id VARCHAR2(50) primary key,
    display_name NVARCHAR2(1000),
    description NVARCHAR2(500),
);

CREATE TABLE openalex.topics_ids (
    topic_id VARCHAR2(50) primary key,
    openalex VARCHAR2(50),
    wikipedia VARCHAR2(3000),
);

CREATE TABLE openalex.funders (
    id VARCHAR2(50) primary key,
    display_name NVARCHAR2(1500),
    alternate_titles NCLOB CHECK (alternate_titles IS JSON),
    country_code VARCHAR2(50),
    description NVARCHAR2(500),
    homepage_url VARCHAR2(1000),
    image_url VARCHAR2(1000),
    image_thumbnail_url VARCHAR2(1000),
    grants_count NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    updated_date TIMESTAMP
);

CREATE TABLE OPENALEX.stage$funders AS
SELECT * FROM OPENALEX.funders WHERE 1 = 0;

CREATE TABLE openalex.funders_ids (
    funder_id VARCHAR2(50) primary key,
    openalex VARCHAR2(50),
    ror VARCHAR2(50),
    wikidata VARCHAR2(50),
    crossref VARCHAR2(50),
    doi VARCHAR2(100)
);

CREATE TABLE OPENALEX.stage$funders_ids AS
SELECT * FROM OPENALEX.funders_ids WHERE 1 = 0;

CREATE TABLE openalex.funders_counts_by_year (
    funder_id VARCHAR2(50),
    year NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    primary key (funder_id,year)
);

CREATE TABLE OPENALEX.stage$funders_counts_by_year AS
SELECT * FROM OPENALEX.funders_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.institutions (
    id VARCHAR2(50) primary key,
    ror VARCHAR2(50),
    display_name NVARCHAR2(1000),
    country_code VARCHAR2(50),
    type VARCHAR2(50),
    homepage_url VARCHAR2(1000),
    image_url VARCHAR2(1000),
    image_thumbnail_url VARCHAR2(1000),
    display_name_acronyms CLOB CHECK (display_name_acronyms IS JSON),
    display_name_alternatives NCLOB CHECK (display_name_alternatives IS JSON),
    works_count NUMBER,
    cited_by_count NUMBER,
    works_api_url VARCHAR2(200),
    updated_date TIMESTAMP
);

CREATE TABLE OPENALEX.stage$institutions AS
SELECT * FROM OPENALEX.institutions WHERE 1 = 0;

CREATE TABLE openalex.institutions_associated_institutions (
    institution_id VARCHAR2(50),
    associated_institution_id VARCHAR2(50),
    relationship VARCHAR2(255),
    primary key (institution_id,associated_institution_id)
);

CREATE TABLE OPENALEX.stage$institutions_associated_institutions AS
SELECT * FROM OPENALEX.institutions_associated_institutions WHERE 1 = 0;

CREATE TABLE openalex.institutions_counts_by_year (
    institution_id VARCHAR2(50),
    year NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER,
    primary key (institution_id,year)
);

CREATE TABLE OPENALEX.stage$institutions_counts_by_year AS
SELECT * FROM OPENALEX.institutions_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.institutions_geo (
    institution_id VARCHAR2(50) primary key,
    city VARCHAR2(500),
    geonames_city_id VARCHAR2(50),
    region VARCHAR2(50),
    country_code VARCHAR2(10),
    country VARCHAR2(100),
    latitude NUMBER,
    longitude NUMBER
);

CREATE TABLE OPENALEX.stage$institutions_geo AS
SELECT * FROM OPENALEX.institutions_geo WHERE 1 = 0;

CREATE TABLE openalex.institutions_ids (
    institution_id VARCHAR2(50) primary key,
    openalex VARCHAR2(50),
    ror VARCHAR2(50),
    grid VARCHAR2(50),
    wikipedia VARCHAR2(3000),
    wikidata VARCHAR2(50),
    mag NUMBER
);

CREATE TABLE OPENALEX.stage$institutions_ids AS
SELECT * FROM OPENALEX.institutions_ids WHERE 1 = 0;

CREATE TABLE openalex.publishers (
    id VARCHAR2(50) primary key,
    display_name NVARCHAR2(1000),
    alternate_titles NCLOB CHECK (alternate_titles IS JSON),
    country_codes CLOB CHECK (country_codes IS JSON),
    hierarchy_level NUMBER,
    parent_publisher VARCHAR2(50),
    works_count NUMBER,
    cited_by_count NUMBER,
    sources_api_url VARCHAR2(200),
    updated_date TIMESTAMP
);

CREATE TABLE OPENALEX.stage$publishers AS
SELECT * FROM OPENALEX.publishers WHERE 1 = 0;

CREATE TABLE openalex.publishers_counts_by_year (
    publisher_id VARCHAR2(50),
    year NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER,
    primary key (publisher_id,year)
);

CREATE TABLE OPENALEX.stage$publishers_counts_by_year AS
SELECT * FROM OPENALEX.publishers_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.publishers_ids (
    publisher_id VARCHAR2(50) primary key,
    openalex VARCHAR2(50),
    ror VARCHAR2(50),
    wikidata VARCHAR2(50)
);

CREATE TABLE OPENALEX.stage$publishers_ids AS
SELECT * FROM OPENALEX.publishers_ids WHERE 1 = 0;

CREATE TABLE openalex.sources (
    id VARCHAR2(50) primary key,
    issn_l VARCHAR2(50),
    issn CLOB CHECK (issn IS JSON),
    display_name NVARCHAR2(1500),
    publisher VARCHAR2(50),
    works_count NUMBER,
    cited_by_count NUMBER,
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    is_in_doaj NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    homepage_url VARCHAR2(1000),
    works_api_url VARCHAR2(1000),
    updated_date TIMESTAMP
);

CREATE TABLE OPENALEX.stage$sources AS
SELECT * FROM OPENALEX.sources WHERE 1 = 0;

CREATE TABLE openalex.sources_counts_by_year (
    source_id VARCHAR2(50),
    year NUMBER,
    works_count NUMBER,
    cited_by_count NUMBER,
    oa_works_count NUMBER,
    primary key (source_id,year)
);

CREATE TABLE OPENALEX.stage$sources_counts_by_year AS
SELECT * FROM OPENALEX.sources_counts_by_year WHERE 1 = 0;

CREATE TABLE openalex.sources_ids (
    source_id VARCHAR2(50) primary key,
    openalex VARCHAR2(50),
    issn_l VARCHAR2(50),
    issn CLOB CHECK (issn IS JSON),
    mag NUMBER,
    wikidata VARCHAR2(50),
    fatcat VARCHAR2(100)
);

CREATE TABLE OPENALEX.stage$sources_ids AS
SELECT * FROM OPENALEX.sources_ids WHERE 1 = 0;

CREATE TABLE openalex.works (
    id VARCHAR2(50) primary key,
    doi VARCHAR2(100),
    title NVARCHAR2(1500),
    display_name NVARCHAR2(1500),
    publication_year NUMBER,
    publication_date DATE,
    type VARCHAR2(50),
    cited_by_count NUMBER,
    is_retracted NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    is_paratext NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    cited_by_api_url VARCHAR2(200),
    -- abstract_inverted_index CLOB CHECK (abstract_inverted_index IS JSON),
    language VARCHAR2(50)
);

ALTER TABLE openalex.works
MODIFY PARTITION BY HASH(id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works AS
SELECT * FROM OPENALEX.works WHERE 1 = 0;

CREATE TABLE openalex.works_primary_locations (
    work_id VARCHAR2(50),
    source_id VARCHAR2(50),
    landing_page_url VARCHAR2(1000),
    pdf_url VARCHAR2(1000),
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    version VARCHAR2(50),
    license VARCHAR2(50),
    primary key (work_id,source_id)
);

ALTER TABLE openalex.works_primary_locations
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_primary_locations AS
SELECT * FROM OPENALEX.works_primary_locations WHERE 1 = 0;

CREATE TABLE openalex.works_locations (
    work_id VARCHAR2(50),
    source_id VARCHAR2(50),
    landing_page_url VARCHAR2(1000),
    pdf_url VARCHAR2(1000),
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    version VARCHAR2(50),
    license VARCHAR2(50),
    primary key (work_id,source_id)
);

ALTER TABLE openalex.works_locations
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_locations AS
SELECT * FROM OPENALEX.works_locations WHERE 1 = 0;

CREATE TABLE openalex.works_best_oa_locations (
    unique_id raw(16) default sys_guid(),
    work_id VARCHAR2(50),
    source_id VARCHAR2(50),
    landing_page_url VARCHAR2(1000),
    pdf_url VARCHAR2(1500),
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    version VARCHAR2(50),
    license VARCHAR2(50),
    -- unfortunately source_id can be blank, as well as landing_page_url or pdf_url
    -- so creating a unique_id to make it simpler
    primary key (unique_id)
);

ALTER TABLE openalex.works_best_oa_locations
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_best_oa_locations AS
SELECT * FROM OPENALEX.works_best_oa_locations WHERE 1 = 0;

ALTER TABLE openalex.stage$works_best_oa_locations
DROP COLUMN UNIQUE_ID;


CREATE TABLE openalex.works_authorships (
    work_id VARCHAR2(50),
    author_position VARCHAR2(50),
    author_id VARCHAR2(50),
    institution_id VARCHAR2(50),
    raw_affiliation_string CLOB,
    primary key (work_id,author_id)
);

ALTER TABLE openalex.works_authorships
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_authorships AS
SELECT * FROM OPENALEX.works_authorships WHERE 1 = 0;

CREATE TABLE openalex.works_biblio (
    work_id VARCHAR2(50) primary key,
    volume VARCHAR2(50),
    issue VARCHAR2(100),
    first_page VARCHAR2(50),
    last_page VARCHAR2(50)
);

ALTER TABLE openalex.works_biblio
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_biblio AS
SELECT * FROM OPENALEX.works_biblio WHERE 1 = 0;

CREATE TABLE openalex.works_concepts (
    work_id VARCHAR2(50),
    concept_id VARCHAR2(50),
    score NUMBER,
    primary key (work_id,concept_id)
);

ALTER TABLE openalex.works_concepts
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_concepts AS
SELECT * FROM OPENALEX.works_concepts WHERE 1 = 0;

CREATE TABLE openalex.works_ids (
    work_id VARCHAR2(50) primary key,
    openalex VARCHAR2(50),
    doi VARCHAR2(100),
    mag NUMBER,
    pmid VARCHAR2(100),
    pmcid VARCHAR2(100)
);

ALTER TABLE openalex.works_ids
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_ids AS
SELECT * FROM OPENALEX.works_ids WHERE 1 = 0;

CREATE TABLE openalex.works_mesh (
    work_id VARCHAR2(50),
    merge_id VARCHAR2(100),
    descriptor_ui VARCHAR2(50),
    descriptor_name VARCHAR2(150),
    qualifier_ui VARCHAR2(50),
    qualifier_name VARCHAR2(100),
    is_major_topic NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    primary key (work_id,merge_id)
);

ALTER TABLE openalex.works_mesh
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_mesh AS
SELECT * FROM OPENALEX.works_mesh WHERE 1 = 0;

CREATE TABLE openalex.works_open_access (
    work_id VARCHAR2(50) primary key,
    is_oa NUMBER(1,0),  -- Assuming 1 or 0 for boolean values
    oa_status VARCHAR2(50),
    oa_url VARCHAR2(1500),
    any_repository_has_fulltext NUMBER(1,0)  -- Assuming 1 or 0 for boolean values
);

ALTER TABLE openalex.works_open_access
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_open_access AS
SELECT * FROM OPENALEX.works_open_access WHERE 1 = 0;

CREATE TABLE openalex.works_referenced_works (
    work_id VARCHAR2(50),
    referenced_work_id VARCHAR2(50),
    primary key (work_id,referenced_work_id)
);

ALTER TABLE openalex.works_referenced_works
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_referenced_works AS
SELECT * FROM OPENALEX.works_referenced_works WHERE 1 = 0;

CREATE TABLE openalex.works_related_works (
    work_id VARCHAR2(50),
    related_work_id VARCHAR2(50),
    primary key (work_id,related_work_id)
);

ALTER TABLE openalex.works_related_works
MODIFY PARTITION BY HASH(work_id) PARTITIONS 8;

CREATE TABLE OPENALEX.stage$works_related_works AS
SELECT * FROM OPENALEX.works_related_works WHERE 1 = 0;