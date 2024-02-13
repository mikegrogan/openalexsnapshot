-- Grant SELECT, INSERT, UPDATE, DELETE privileges on all tables in OPENALEX schema to another user
BEGIN
  FOR t IN (SELECT table_name FROM all_tables WHERE owner = 'OPENALEX') LOOP
    EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON OPENALEX.' || t.table_name || ' TO [SCHEMA]';
  END LOOP;
END;
/