# Database Migration Safety & Guard Reference

This guide provides deep technical context on the core safety constraints enforced by our database hooks.

## 1. Additive-Only Migrations

Catastrophic data loss (such as accidental drops of active tables or schema truncates) is the highest risk during deployments. To mitigate this risk, all schema migrations targeting production databases are mandated to be strictly additive:

### Allowed (Additive) Operations:
*   `CREATE TABLE ...`
*   `ALTER TABLE ... ADD COLUMN ...`
*   `ALTER TABLE ... ALTER COLUMN ...` (widening types or making columns nullable)
*   `CREATE INDEX ...`

### Forbidden (Destructive) Operations:
*   `DROP TABLE ...` (destroys data)
*   `DROP COLUMN ...` (destroys columns)
*   `TRUNCATE TABLE ...` / `TRUNCATE ...` (wipes tables)
*   `DELETE FROM ...` (destroys rows)

### Reorganizing Safely:
If you need to rename or remove a column, follow the safe expansion-contraction pattern across separate releases:
1.  **Phase 1 (Expand)**: Add the new column (additive). Keep the old column on disk.
2.  **Phase 2 (Backfill)**: Deploy application code to read from/write to both columns, and backfill existing rows.
3.  **Phase 3 (Contract)**: Deploy application code to read only from the new column. Once verified, run a separate offline schema migration to drop the old column.

---

## 2. The `CONCURRENTLY` Transaction Trap

Standard database migration engines (such as `golang-migrate`, `flyway`, etc.) automatically wrap the execution of each SQL migration file in an active database transaction block (e.g. `BEGIN; ... COMMIT;`). This is done to ensure that if a migration fails halfway, it rolls back cleanly.

### The Trap:
PostgreSQL strictly prohibits running `CREATE INDEX CONCURRENTLY` inside an active transaction block. If attempted, Postgres will throw a fatal exception:
`ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block`

This causes the entire migration run to abort and crash.

### How to Build Concurrent Indexes Safely:
1.  **Use standard creation**: If the table is small or being created in the same migration, use standard `CREATE INDEX` (runs cleanly inside transaction).
2.  **Disable transaction wrapping**: If the table is large and requires `CONCURRENTLY` in production, you must configure your migration engine to run that specific migration *outside* a transaction block (e.g. adding a file-level directive if supported, or applying the index manually ahead of the migration run).
