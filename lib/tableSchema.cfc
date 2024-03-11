component accessors="true" extends="helper" {

  property name="tables";
  property name="schema";

  function init(){
    this.setschema(application.database.schema);

    // import mode can be set to: merge, append

    this.setTables({
      authors: {
        fields: [
          {
            name: "authors",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,orcid,display_name,display_name_alternatives,works_count,cited_by_count,last_known_institution,works_api_url,updated_date",
            active: true
          },
          {
            name: "authors_affiliations",
            id: "author_id",
            fields: "author_id,institution_id,year",
            active: true
          },
          {
            name: "authors_counts_by_year",
            id: "author_id",
            fields: "author_id,year,snapshotdate,snapshotfilenumber,works_count,cited_by_count,oa_works_count",
            active: true
          },
          {
            name: "authors_ids",
            id: "author_id",
            fields: "author_id,snapshotdate,snapshotfilenumber,openalex,orcid,scopus,twitter,wikipedia,mag",
            active: true
          }
        ],
        importmode: "append"
      },
      concepts: {
        fields: [
          {
            name: "concepts",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,wikidata,display_name,concept_level,description,works_count,cited_by_count,image_url,image_thumbnail_url,works_api_url,updated_date",
            active: true
          },
          {
            name: "concepts_ancestors",
            id: "concept_id",
            fields: "concept_id,ancestor_id,snapshotdate,snapshotfilenumber",
            active: true
          },
          {
            name: "concepts_counts_by_year",
            id: "concept_id",
            fields: "concept_id,year,snapshotdate,snapshotfilenumber,works_count,cited_by_count,oa_works_count",
            active: true
          },
          {
            name: "concepts_ids",
            id: "concept_id",
            fields: "concept_id,snapshotdate,snapshotfilenumber,openalex,wikidata,wikipedia,umls_aui,umls_cui,mag",
            active: true
          },
          {
            name: "concepts_related_concepts",
            id: "concept_id",
            fields: "concept_id,related_concept_id,snapshotdate,snapshotfilenumber,score",
            active: true
          }
        ],
        importmode: "merge"
      },
      domains: {
        fields: [
          {
            name: "domains",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,display_name,display_name_alternatives,description,works_count,cited_by_count,works_api_url,updated_date",
            active: true
          },
          {
            name: "domains_fields",
            id: "domain_id",
            fields: "domain_id,field_id,snapshotdate,snapshotfilenumber",
            active: true
          },
          {
            name: "domains_ids",
            id: "domain_id",
            fields: "domain_id,snapshotdate,snapshotfilenumber,wikidata,wikipedia",
            active: true
          },
          {
            name: "domains_siblings",
            id: "domain_id",
            fields: "domain_id,sibling_id,snapshotdate,snapshotfilenumber",
            active: true
          }
        ],
        importmode: "merge"
      },
      fields: {
        fields: [
          {
            name: "fields",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,display_name,display_name_alternatives,description,domain_id,works_count,cited_by_count,works_api_url,updated_date",
            active: true
          },
          {
            name: "fields_ids",
            id: "field_id",
            fields: "field_id,snapshotdate,snapshotfilenumber,wikidata,wikipedia",
            active: true
          },
          {
            name: "fields_siblings",
            id: "field_id",
            fields: "field_id,sibling_id,snapshotdate,snapshotfilenumber",
            active: true
          },
          {
            name: "fields_subfields",
            id: "field_id",
            fields: "field_id,subfield_id,snapshotdate,snapshotfilenumber",
            active: true
          }
        ],
        importmode: "merge"
      },
      funders: {
        fields: [
          {
            name: "funders",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,display_name,alternate_titles,country_code,description,homepage_url,image_url,image_thumbnail_url,grants_count,works_count,cited_by_count,updated_date",
            active: true
          },
          {
            name: "funders_counts_by_year",
            id: "funder_id",
            fields: "funder_id,year,snapshotdate,snapshotfilenumber,works_count,cited_by_count",
            active: true
          },
          {
            name: "funders_ids",
            id: "funder_id",
            fields: "funder_id,snapshotdate,snapshotfilenumber,openalex,ror,wikidata,crossref,doi",
            active: true
          }
        ],
        importmode: "merge"
      },
      institutions: {
        fields: [
          {
            name: "institutions",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,ror,display_name,country_code,type,homepage_url,image_url,image_thumbnail_url,display_name_acronyms,display_name_alternatives,works_count,cited_by_count,works_api_url,updated_date",
            active: true
          },
          {
            name: "institutions_associated_institutions",
            id: "institution_id",
            fields: "institution_id,associated_institution_id,snapshotdate,snapshotfilenumber,relationship",
            active: true
          },
          {
            name: "institutions_counts_by_year",
            id: "institution_id",
            fields: "institution_id,year,snapshotdate,snapshotfilenumber,works_count,cited_by_count,oa_works_count",
            active: true
          },
          {
            name: "institutions_geo",
            id: "institution_id",
            fields: "institution_id,snapshotdate,snapshotfilenumber,city,geonames_city_id,region,country_code,country,latitude,longitude",
            active: true
          },
          {
            name: "institutions_ids",
            id: "institution_id",
            fields: "institution_id,snapshotdate,snapshotfilenumber,openalex,ror,grid,wikipedia,wikidata,mag",
            active: true
          }
        ],
        importmode: "merge"
      },
      publishers: {
        fields: [
          {
            name: "publishers",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,display_name,alternate_titles,country_codes,hierarchy_level,parent_publisher,homepage_url,image_url,image_thumbnail_url,works_count,cited_by_count,sources_api_url,updated_date",
            active: true
          },
          {
            name: "publishers_counts_by_year",
            id: "publisher_id",
            fields: "publisher_id,year,snapshotdate,snapshotfilenumber,works_count,cited_by_count,oa_works_count",
            active: true
          },
          {
            name: "publishers_ids",
            id: "publisher_id",
            fields: "publisher_id,snapshotdate,snapshotfilenumber,openalex,ror,wikidata",
            active: true
          }
        ],
        importmode: "merge"
      },
      sources: {
        fields: [
          {
            name: "sources",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,issn_l,issn,display_name,publisher,works_count,cited_by_count,is_oa,is_in_doaj,homepage_url,works_api_url,updated_date",
            active: true
          },
          {
            name: "sources_counts_by_year",
            id: "source_id",
            fields: "source_id,year,snapshotdate,snapshotfilenumber,works_count,cited_by_count,oa_works_count",
            active: true
          },
          {
            name: "sources_ids",
            id: "source_id",
            fields: "source_id,snapshotdate,snapshotfilenumber,openalex,issn_l,issn,mag,wikidata,fatcat",
            active: true
          }
        ],
        importmode: "merge"
      },
      subfields: {
        fields: [
          {
            name: "subfields",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,display_name,display_name_alternatives,description,field_id,domain_id,works_count,cited_by_count,works_api_url,updated_date",
            active: true
          },
          {
            name: "subfields_ids",
            id: "subfield_id",
            fields: "subfield_id,snapshotdate,snapshotfilenumber,wikidata,wikipedia",
            active: true
          },
          {
            name: "subfields_siblings",
            id: "subfield_id",
            fields: "subfield_id,sibling_id,snapshotdate,snapshotfilenumber",
            active: true
          },
          {
            name: "subfields_topics",
            id: "subfield_id",
            fields: "subfield_id,topic_id,snapshotdate,snapshotfilenumber",
            active: true
          }
        ],
        importmode: "merge"
      },
      topics: {
        fields: [
          {
            name: "topics",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,display_name,description,keywords,subfield_id,field_id,domain_id,works_count,cited_by_count,updated_date",
            active: true
          },
          {
            name: "topics_ids",
            id: "topic_id",
            fields: "topic_id,snapshotdate,snapshotfilenumber,openalex,wikipedia",
            active: true
          },
          {
            name: "topics_siblings",
            id: "topic_id",
            fields: "topic_id,sibling_id,snapshotdate,snapshotfilenumber",
            active: true
          }
        ],
        importmode: "merge"
      },
      works: {
        fields: [
          {
            name: "works",
            id: "id",
            fields: "id,snapshotdate,snapshotfilenumber,snapshotdate,snapshotfilenumber,doi,title,display_name,publication_year,publication_date,type,cited_by_count,is_retracted,is_paratext,cited_by_api_url,language",
            active: true
          },
          {
            name: "works_authorships",
            id: "work_id",
            fields: "work_id,author_id,snapshotdate,snapshotfilenumber,author_positionraw_author_name,institution_id,raw_affiliation_string",
            active: true
          },
          {
            name: "works_best_oa_locations",
            id: "work_id",
            fields: "unique_id,snapshotdate,snapshotfilenumber,work_id,source_id,landing_page_url,pdf_url,is_oa,version,license",
            active: true
          },
          {
            name: "works_biblio",
            id: "work_id",
            fields: "work_id,snapshotdate,snapshotfilenumber,volume,issue,first_page,last_page",
            active: true
          },
          {
            name: "works_concepts",
            id: "work_id",
            fields: "work_id,concept_id,snapshotdate,snapshotfilenumber,score",
            active: true
          },
          {
            name: "works_ids",
            id: "work_id",
            fields: "work_id,snapshotdate,snapshotfilenumber,openalex,doi,mag,pmid,pmcid",
            active: true
          },
          {
            name: "works_locations",
            id: "work_id",
            fields: "unique_id,work_id,source_id,snapshotdate,snapshotfilenumber,landing_page_url,pdf_url,is_oa,version,license",
            active: true
          },
          {
            name: "works_mesh",
            id: "work_id",
            fields: "work_id,merge_id,snapshotdate,snapshotfilenumber,descriptor_ui,descriptor_name,qualifier_ui,qualifier_name,is_major_topic",
            active: true
          },
          {
            name: "works_open_access",
            id: "work_id",
            fields: "work_id,snapshotdate,snapshotfilenumber,is_oa,oa_status,oa_url,any_repository_has_fulltext",
            active: true
          },
          {
            name: "works_primary_locations",
            id: "work_id",
            fields: "unique_id,work_id,source_id,snapshotdate,snapshotfilenumber,landing_page_url,pdf_url,is_oa,version,license",
            active: true
          },
          {
            name: "works_referenced_works",
            id: "work_id",
            fields: "work_id,referenced_work_id,snapshotdate,snapshotfilenumber",
            active: true
          },
          {
            name: "works_related_works",
            id: "work_id",
            fields: "work_id,related_work_id,snapshotdate,snapshotfilenumber",
            active: true
          },
          {
            name: "works_topics",
            id: "work_id",
            fields: "work_id,topic_id,snapshotdate,snapshotfilenumber,score,subfield_id,field_id,domain_id",
            active: true
          }
        ],
        importmode: "append"
      },
      // mergeids is always merge
      mergeids: {fields: [{name: "mergeids", id: "", fields: "merge_date,id,merge_into_id", active: true}], importmode: "merge"}
    });
    return this;
  }

  public function clearStagingTables(entity){
    var result = {success: true};

    for (var table in getActiveTables(arguments.entity)){
      queryExecute(
        "truncate table #this.getSchema()#.stage$#table.name#",
        {},
        {datasource: getDatasource(), result: "truncateQryResult"}
      );

      if (isStruct(truncateQryResult)){
        outputSuccess("Truncated staging table stage$#table.name#");
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  public function clearMainTablesPastSnapshot(entity, latestSnapshot) hint="Only applies to append mode"{
    var result = {success: true};

    outputH2("Checking and deleting any #arguments.entity# table records beyond sync snapshot (append mode only)");
    for (var table in getActiveTables(arguments.entity)){
      queryExecute(
        "delete FROM #this.getSchema()#.#table.name#
        WHERE (snapshotdate > :snapshotdate
            OR (snapshotdate = :snapshotdate AND snapshotfilenumber > :snapshotfile))",
        {
          snapshotdate: {value: arguments.latestsnapshot.snapshotdate, cfsqltype: "date"},
          snapshotfile: {value: arguments.latestsnapshot.snapshotfile, cfsqltype: "varchar"}
        },
        {datasource: getDatasource(), result: "deleteQryResult"}
      );

      if (isStruct(deleteQryResult)){
        outputSuccess("Deleted #deleteQryResult.recordcount# from  main table #table.name#");
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  public function rebuildPrimaryKeyIndex(entity) hint="Only applies to append mode"{
    var result = {success: true};

    outputH3("Rebuilding #arguments.entity# primary key table index (append mode only)");
    for (var table in getActiveTables(arguments.entity)){
      queryExecute(
        "alter index #this.getSchema()#.pk_#table.name# rebuild",
        {},
        {datasource: getDatasource(), result: "qryResult"}
      );

      if (isStruct(qryResult)){
        outputSuccess("#getElapsedTime(qryresult.executiontime)# Rebuilt #table.name# primary key index");
        flush;
      }
      else{
        result.success = false;
      }
    }

    return result;
  }

  public function isTableinEntityList(entity, tablaname){
    var result = {success: false, data: {}};

    var simplifiedname = arguments.tablaname.reReplaceNocase("_", "", "all");
    var check = getActiveTables(arguments.entity).filter((row) => {
      return row.name == simplifiedname;
    });

    if (check.len() == 1){
      result.success = true;
      result.data = check[1];
    }
    return result;
  }

  public function getActiveTables(entity){
    return this.getTables()[arguments.entity]["fields"].filter((row) => {
      return row.active == true;
    });
  }

  public function getEntityImportMode(entity){
    return this.getTables()[arguments.entity]["importmode"];
  }

  public function getActiveTableNamesList(entity){
    // simplifying table name to remove underscores
    return getActiveTables(arguments.entity).reduce((result, row) => {
      var simplifiedname = row.name.reReplaceNocase("_", "", "all");
      return result.listappend(simplifiedname);
    }, "");
  }

}
