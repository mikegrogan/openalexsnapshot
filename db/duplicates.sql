-- ideas on how to remove duplicates
-- dealing with any constraints/indexes will have to be done first.
-- duplicates might be a result of the append into table mode in sqlloader
-- the coldfusion script attemppts to mitigate that, but just in case

DELETE FROM WORKS
WHERE ROWID NOT IN (
    SELECT MIN(ROWID)
    FROM WORKS
    GROUP BY work_id
);

DELETE FROM WORKS_AUTHORSHIPS
WHERE ROWID NOT IN (
    SELECT MIN(ROWID)
    FROM WORKS_AUTHORSHIPS
    GROUP BY work_id,author_id
);

DELETE FROM WORKS_BEST_OA_LOCATIONS
WHERE ROWID NOT IN (
    SELECT MIN(ROWID)
    FROM WORKS_BEST_OA_LOCATIONS
    GROUP BY WORK_ID,SOURCE_ID,LANDING_PAGE_URL,PDF_URL,IS_OA,VERSION,LICENSE
);

DELETE FROM WORKS_BIBLIO
WHERE ROWID NOT IN (
    SELECT MIN(ROWID)
    FROM WORKS_BIBLIO
    GROUP BY work_id
);

DELETE FROM WORKS_CONCEPTS
WHERE ROWID NOT IN (
    SELECT MIN(ROWID)
    FROM WORKS_CONCEPTS
    GROUP BY work_id,concept_id
);