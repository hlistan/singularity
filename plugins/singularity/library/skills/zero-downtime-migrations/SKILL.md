---
name: zero-downtime-migrations
description: Schema and data migrations for a database that serves traffic while a deploy rolls out, so old and new code both keep working. For planning, implementing and reviewing changes that touch migrations.
---

# Zero-downtime migrations

During a rolling deploy the previous release and the new one run against the same database. Every migration must work with both, and no statement may hold a lock that stalls traffic. Project specifics (the migration tool, how to run migrations locally, released migrations that are append-only) are in the project's guidelines.

## Expand, migrate, contract

Change a schema in steps, each its own deploy (parallel change: D. Sato, martinfowler.com, 2014; Stripe, *Online migrations at scale*, 2017):

1. **Expand**: additive only: a new table, a nullable column or one with a constant default, a new index built online. The old code keeps working.
2. **Write both**: the new code writes the old and the new shape, and reads the old one.
3. **Backfill**: copy existing rows in batches, outside the schema migration; idempotent and resumable; throttled on large tables.
4. **Read new**: switch reads, after verifying the backfill.
5. **Contract**: drop the old column or table in a later release, once no running code reads it.

Never in one release: rename or drop a column or table that the previous release reads; change a column's type in place; add `NOT NULL` to a populated column without the safe sequence below.

## Locks (PostgreSQL)

- DDL waiting for its lock blocks every query behind it: set `lock_timeout` (a few seconds) on each migration and retry rather than queue.
- Indexes: `CREATE INDEX CONCURRENTLY` (outside a transaction block; a failed build leaves an invalid index to drop). Same for `DROP INDEX CONCURRENTLY`.
- Constraints: add `CHECK` and `FOREIGN KEY` as `NOT VALID`, then `VALIDATE CONSTRAINT` in a later migration (it allows reads and writes while it scans).
- `NOT NULL` on a populated column: a valid `CHECK (col IS NOT NULL)` constraint first (as above); from PostgreSQL 12, `SET NOT NULL` then skips the table scan.
- `ADD COLUMN` with a constant default doesn't rewrite the table from PostgreSQL 11; a volatile default (`now()`, `random()`) still does.
- A type change usually rewrites the table: expand and contract instead.

## Locks (MySQL)

- InnoDB online DDL: state `ALGORITHM=INSTANT` or `INPLACE` with `LOCK=NONE`, so the statement fails instead of silently copying the table.
- Large tables where online DDL can't apply: an online schema-change tool (`gh-ost`, `pt-online-schema-change`).

## Reversibility and tests

- Every migration has a down path, or the plan says why not; contract steps are one-way, so they ship only after the new code has run in production.
- Test each migration up, down and up again in CI; a backfill also on data with nulls, duplicates and the largest realistic volume.

## Review checklist

- Does the previous release still work against the migrated schema?
- Does any statement take a long exclusive lock on a large table?
- Is a backfill in the same transaction as DDL, or unbatched?
- Does a new foreign key have an index on its referencing column?

Sources: PostgreSQL documentation (`ALTER TABLE`, `CREATE INDEX`); MySQL 8 documentation, *Online DDL Operations*; GitLab documentation, *Avoiding downtime in migrations*.
