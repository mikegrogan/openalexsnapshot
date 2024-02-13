component accessors="true" extends="helper" {

  property name="tables";
  property name="schema";

  function init(){
    this.setschema(application.database.schema);
    this.setTables({
      authors: [
        {
          name: "authors",
          id: "id",
          fields: "id,orcid,display_name,display_name_alternatives,works_count,cited_by_count,last_known_institution,works_api_url,updated_date",
          active: true
        },
        {
          name: "authors_counts_by_year",
          id: "author_id",
          fields: "author_id,year,works_count,cited_by_count,oa_works_count",
          active: true
        },
        {
          name: "authors_ids",
          id: "author_id",
          fields: "author_id,openalex,orcid,scopus,twitter,wikipedia,mag",
          active: true
        }
      ],
      concepts: [
        {
          name: "concepts",
          id: "id",
          fields: "id,wikidata,display_name,concept_level,description,works_count,cited_by_count,image_url,image_thumbnail_url,works_api_url,updated_date",
          active: true
        },
        {name: "concepts_ancestors", id: "concept_id", fields: "concept_id,ancestor_id", active: true},
        {
          name: "concepts_counts_by_year",
          id: "concept_id",
          fields: "concept_id,year,works_count,cited_by_count,oa_works_count",
          active: true
        },
        {
          name: "concepts_ids",
          id: "concept_id",
          fields: "concept_id,openalex,wikidata,wikipedia,umls_aui,umls_cui,mag",
          active: true
        },
        {
          name: "concepts_related_concepts",
          id: "concept_id",
          fields: "concept_id,related_concept_id,score",
          active: true
        }
      ],
      institutions: [
        {
          name: "institutions",
          id: "id",
          fields: "id,ror,display_name,country_code,type,homepage_url,image_url,image_thumbnail_url,display_name_acronyms,display_name_alternatives,works_count,cited_by_count,works_api_url,updated_date",
          active: true
        },
        {
          name: "institutions_associated_institutions",
          id: "institution_id",
          fields: "institution_id,associated_institution_id,relationship",
          active: true
        },
        {
          name: "institutions_counts_by_year",
          id: "institution_id",
          fields: "institution_id,year,works_count,cited_by_count,oa_works_count",
          active: true
        },
        {
          name: "institutions_geo",
          id: "institution_id",
          fields: "institution_id,city,geonames_city_id,region,country_code,country,latitude,longitude",
          active: true
        },
        {
          name: "institutions_ids",
          id: "institution_id",
          fields: "institution_id,openalex,ror,grid,wikipedia,wikidata,mag",
          active: true
        }
      ],
      publishers: [
        {
          name: "publishers",
          id: "id",
          fields: "id,display_name,alternate_titles,country_codes,hierarchy_level,parent_publisher,works_count,cited_by_count,sources_api_url,updated_date",
          active: true
        },
        {
          name: "publishers_counts_by_year",
          id: "publisher_id",
          fields: "publisher_id,year,works_count,cited_by_count,oa_works_count",
          active: true
        },
        {
          name: "publishers_ids",
          id: "publisher_id",
          fields: "publisher_id,openalex,ror,wikidata",
          active: true
        }
      ],
      sources: [
        {
          name: "sources",
          id: "id",
          fields: "id,issn_l,issn,display_name,publisher,works_count,cited_by_count,is_oa,is_in_doaj,homepage_url,works_api_url,updated_date",
          active: true
        },
        {
          name: "sources_counts_by_year",
          id: "source_id",
          fields: "source_id,year,works_count,cited_by_count,oa_works_count",
          active: true
        },
        {
          name: "sources_ids",
          id: "source_id",
          fields: "source_id,openalex,issn_l,issn,mag,wikidata,fatcat",
          active: true
        }
      ],
      works: [
        {
          name: "works",
          id: "id",
          fields: "id,doi,title,display_name,publication_year,publication_date,type,cited_by_count,is_retracted,is_paratext,cited_by_api_url,language",
          active: true
        },
        {
          name: "works_authorships",
          id: "work_id",
          fields: "work_id,author_position,author_id,institution_id,raw_affiliation_string",
          active: true
        },
        {
          name: "works_best_oa_locations",
          id: "work_id",
          fields: "unique_id,work_id,source_id,landing_page_url,pdf_url,is_oa,version,license",
          active: true
        },
        {
          name: "works_biblio",
          id: "work_id",
          fields: "work_id,volume,issue,first_page,last_page",
          active: true
        },
        {name: "works_concepts", id: "work_id", fields: "work_id,concept_id,score", active: true},
        {name: "works_ids", id: "work_id", fields: "work_id,openalex,doi,mag,pmid,pmcid", active: true},
        {
          name: "works_locations",
          id: "work_id",
          fields: "work_id,source_id,landing_page_url,pdf_url,is_oa,version,license",
          active: true
        },
        {
          name: "works_mesh",
          id: "work_id",
          fields: "work_id,merge_id,descriptor_ui,descriptor_name,qualifier_ui,qualifier_name,is_major_topic",
          active: true
        },
        {
          name: "works_open_access",
          id: "work_id",
          fields: "work_id,is_oa,oa_status,oa_url,any_repository_has_fulltext",
          active: true
        },
        {
          name: "works_primary_locations",
          id: "work_id",
          fields: "work_id,source_id,landing_page_url,pdf_url,is_oa,version,license",
          active: false
        },
        {name: "works_referenced_works", id: "work_id", fields: "work_id, referenced_work_id", active: true},
        {name: "works_related_works", id: "work_id", fields: "work_id,related_work_id", active: true}
      ]
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
    return this.getTables()[arguments.entity].filter((row) => {
      return row.active == true;
    });
  }

  public function getActiveTableNamesList(entity){
    // simplifying table name to remove underscores
    return getActiveTables(arguments.entity).reduce((result, row) => {
      var simplifiedname = row.name.reReplaceNocase("_", "", "all");
      return result.listappend(simplifiedname);
    }, "");
  }

}