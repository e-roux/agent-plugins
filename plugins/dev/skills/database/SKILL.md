---
name: database
description: Manage database schemas and migrations. Enforces Atlas for declarative PostgreSQL schemas and strictly prohibits manual SQL edits and destructive migrations. Use when modifying schemas, working with SQL or HCL files, or running migrations.
---

# Database Schema & Migration Management

PostgreSQL applications in this workspace are managed strictly through **Atlas** declarative schema authority. Hand-crafting manual SQL migration scripts is strictly prohibited to guarantee schema integrity and prevent database drift.

## Declarative Atlas Workflow

When modifying a database schema, ALWAYS follow this 3-step declarative workflow:

1.  **Edit the desired state**: Modify `db/atlas/schema.hcl` directly to declare your tables, columns, indexes, or constraints.
2.  **Generate the versioned migration**: Generate the safe, auto-diffed SQL migration file by running:
    ```bash
    make atlas.diff ATLAS_NAME=add_your_change_description
    ```
3.  **Review and Apply**: Verify the generated SQL file under `db/atlas/migrations/` and apply it locally:
    ```bash
    make atlas.apply
    ```

## Core Migration Safety Rules

All schemas and migrations must comply with these foundational security and transaction-safety rules:

*   **Additive-Only**: To prevent catastrophic production data loss, all migrations must be strictly additive. Do NOT use destructive commands such as `DROP TABLE`, `DROP COLUMN`, `TRUNCATE`, or `DELETE`. See [references/safety-guards.md](references/safety-guards.md).
*   **Transaction-Safety**: Never execute `CREATE INDEX CONCURRENTLY` inside standard transaction-wrapped migrations, as PostgreSQL forbids concurrent index creation inside transactions. See [references/safety-guards.md](references/safety-guards.md).
*   **Naming & Ordering**: All migrations directories must maintain strict sequential, non-overlapping prefixes. Do not hand-edit or modify already-applied migrations or their cryptographic sum file (`atlas.sum`).
