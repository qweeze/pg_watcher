/*
This schema provides a set of functions to monitor changes in data returned by an arbitrary query

Usage example:
    CREATE TABLE books (_id SERIAL, title TEXT, author TEXT);
    SELECT watcher.add_query('myquery', 'select * from books');
    INSERT INTO books (title) VALUES ('The Very Hungry Caterpillar');
    SELECT * FROM watcher.get_changes('myquery');
    SELECT watcher.reset_changes('myquery');
*/

CREATE SCHEMA IF NOT EXISTS watcher;
COMMENT ON SCHEMA watcher IS 'Schema for data changes monitoring';


CREATE OR REPLACE FUNCTION watcher.add_query(query_key TEXT, query TEXT) RETURNS VOID AS $$
BEGIN
    EXECUTE format('CREATE VIEW watcher.%s_view AS %s', query_key, query);
    EXECUTE format('CREATE MATERIALIZED VIEW watcher.%s_mat_view AS SELECT * FROM watcher.%s_view', query_key, query_key);
    EXECUTE format('CREATE SEQUENCE watcher.%s_seq', query_key);
END
$$ language plpgsql;


CREATE OR REPLACE FUNCTION watcher.drop_query(query_key TEXT) RETURNS VOID AS $$
BEGIN
    EXECUTE format('DROP MATERIALIZED VIEW watcher.%s_mat_view', query_key);
    EXECUTE format('DROP VIEW watcher.%s_view', query_key);
    EXECUTE format('DROP SEQUENCE watcher.%s_seq', query_key);
END
$$ language plpgsql;


CREATE OR REPLACE FUNCTION watcher.get_seq_number(query_key TEXT, OUT sequence_num BIGINT) AS $$
BEGIN
    EXECUTE format('SELECT last_value FROM watcher.%s_seq', query_key) INTO sequence_num;
END
$$ language plpgsql;


CREATE OR REPLACE FUNCTION watcher.inc_seq_number(query_key TEXT) RETURNS VOID AS $$
BEGIN
    EXECUTE format('SELECT nextval(''watcher.%s_seq'')', query_key);
END
$$ language plpgsql;


CREATE OR REPLACE FUNCTION watcher.list_queries() RETURNS TABLE (query_key TEXT, query TEXT) AS $$
BEGIN
    RETURN QUERY SELECT
        left(table_name, -5) AS query_key,
        view_definition::TEXT AS query
    FROM information_schema.views WHERE table_schema = 'watcher' AND table_name LIKE '%_view';
END
$$ language plpgsql;


CREATE OR REPLACE FUNCTION watcher.reset_changes(query_key TEXT) RETURNS VOID AS $$
BEGIN
    EXECUTE format('REFRESH MATERIALIZED VIEW watcher.%s_mat_view', query_key);
END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION watcher.get_changes(query_key TEXT)
RETURNS TABLE (
    identifier TEXT,
    operation CHAR(1),
    old_values JSONB,
    new_values JSONB,
    change_id BIGINT
) AS $$
BEGIN
    RETURN QUERY EXECUTE format(
        'SELECT
            COALESCE(old._id, new._id)::TEXT as identifier,

            CASE
                WHEN old IS NULL THEN ''I''::CHAR(1)
                WHEN new IS NULL THEN ''D''::CHAR(1)
                ELSE ''U''::CHAR(1)
            END as operation,

            to_jsonb(old.*) - ''_id'' AS old_values,

            to_jsonb(new.*) - ''_id'' AS new_values,

            nextval(''watcher.%s_seq'') AS change_id
        FROM
            watcher.%s_mat_view old
        FULL OUTER JOIN
            watcher.%s_view new
        USING (_id)
        WHERE old._id is NULL OR new._id is NULL OR old.* <> new.*',
        query_key, query_key, query_key
    );
END
$$ LANGUAGE plpgsql;
