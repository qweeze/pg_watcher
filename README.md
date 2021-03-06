### pg_watcher

A set of PL/pgSQL functions to monitor data changes (CDC) as a result of an arbitrary SQL query

Changes are computed by comparing result of a query against a materialized view based on the same query. A query must have `_id` column which is used to join it with the materialized view.

##### Usage example:

```sql
test=# CREATE TABLE books (_id SERIAL, title TEXT, author TEXT);
CREATE TABLE

test=# SELECT watcher.add_query('myquery', 'select * from books');
-[ RECORD 1 ]
add_query |

test=# INSERT INTO books (title) VALUES ('The Very Hungry Caterpillar');
INSERT 0 1

test=# --We have 1 insert (operation = 'I') after query was added for watching
test=# SELECT * FROM watcher.get_changes('myquery');
-[ RECORD 1 ]--------------------------------------------------------
identifier | 1
operation  | I
old_values |
new_values | {"title": "The Very Hungry Caterpillar", "author": null}
change_id  | 1

test=# --Mark changes as read
test=# SELECT watcher.reset_changes('myquery');
-[ RECORD 1 ]-+-
reset_changes |

test=# SELECT * FROM watcher.get_changes('myquery');
(0 rows)

test=# UPDATE books SET title = 'New title' where _id = 1;
UPDATE 1

test=# SELECT * FROM watcher.get_changes('myquery');
-[ RECORD 1 ]--------------------------------------------------------
identifier | 1
operation  | U
old_values | {"title": "The Very Hungry Caterpillar", "author": null}
new_values | {"title": "New title", "author": null}
change_id  | 2
```
