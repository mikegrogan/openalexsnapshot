-- Grant SELECT, INSERT, UPDATE, DELETE privileges on all tables in OPENALEX schema to another user
BEGIN
  FOR t IN (SELECT table_name FROM all_tables WHERE owner = 'OPENALEX') LOOP
    EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON OPENALEX.' || t.table_name || ' TO [SCHEMA]';
  END LOOP;
END;
/

-- doesn't quite work. needs dba role possibly
BEGIN
FOR idx IN (SELECT index_name FROM all_indexes WHERE table_owner = 'OPENALEX') LOOP
  EXECUTE IMMEDIATE 'GRANT ALTER ON OPENALEX.' || idx.index_name || ' TO [SCHEMA]';
END LOOP;
end;
/