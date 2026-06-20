# Billiard Salon Management System — SQL Server Data Warehouse

An end-to-end SQL Server project: normalized OLTP design, dimensional modeling, a re-runnable ETL pipeline, and automated change tracking via triggers. Built for the Advanced Database Systems course, BSc Data Science in Business, Corvinus University of Budapest (2025).

## Run order

Run the scripts in this order — each assumes the previous has run:

1. **`normalised.sql`** — creates the 3NF OLTP schema (8 tables) and loads it from the raw CSV
2. **`bill_timestamps_triggers.sql`** — adds change-tracking triggers to the source tables
3. **`billdimensional.sql`** — creates the dimensional warehouse and performs the initial full load
4. **`bill_etl_merge.sql`** — re-runnable incremental sync (OLTP → warehouse)

## Files

| File | Description |
|---|---|
| `normalised.sql` | 3NF OLTP schema (8 tables) seeded from a flat CSV using `DENSE_RANK()` / `ROW_NUMBER()` for surrogate keys |
| `bill_timestamps_triggers.sql` | `AFTER INSERT, UPDATE` triggers on the 6 source tables, stamping `modifiedon` |
| `billdimensional.sql` | Dimensional warehouse (5 dimensions, 2 fact tables, 1 bridge) + full load via `INSERT...SELECT` |
| `bill_etl_merge.sql` | ETL pipeline: 8 `MERGE` statements syncing OLTP → warehouse (upsert + delete) |

## Schema

**OLTP (`normalised.sql`)**
`customers`, `staff`, `tabletypes`, `billiardtables`, `services`, `sessions`, `session_services`, `payments`
- Seeded from the flat staging table `billiard.[billiard salon management]`
- `DENSE_RANK()` generates entity surrogate keys; `ROW_NUMBER()` generates payment keys

**Warehouse (`billdimensional.sql`)**
- Dimensions: `dim_customer`, `dim_staff`, `dim_billiardtable`, `dim_service`, `dim_date`
- Facts: `fact_session`, `fact_payment`
- Bridge: `fact_session_service` (resolves the session ↔ service many-to-many)

Because two fact tables share conformed dimensions, this is a **galaxy (fact-constellation)** schema rather than a single star.

## ETL

- **Initial load** (`billdimensional.sql`): plain `INSERT...SELECT`, correct for a first, empty load.
- **Incremental sync** (`bill_etl_merge.sql`): 8 `MERGE` statements. Dimensions use full upsert (insert / update / delete); fact tables are insert + delete only, since a fact row is never updated.

## Tech

SQL Server (T-SQL) — 3NF normalization, dimensional modeling, window functions, `MERGE`, triggers, ETL.
