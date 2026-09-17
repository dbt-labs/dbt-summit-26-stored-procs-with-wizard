# dbt Summit 2026: Migrating Stored Procedures with dbt Wizard

## Showing username in workshop 

dbt show --inline "select current_user()" --limit 1

## Training Survey (pls fill out :D)

https://dbtlearn.typeform.com/dbt-summit-labs

## Slides

[Migrate Stored Procs with dbt Wizard - HOL Deck.pdf](https://github.com/user-attachments/files/32065959/WIP.Migrate.Stored.Procs.with.dbt.Wizard.-.HOL.Deck.pdf)


## What this repository is

This is a hands-on dbt workshop repository for migrating the Snowflake stored procedure `sp_load_order_profitability` into a tested, documented dbt DAG using dbt Wizard.

The legacy procedure combines raw ingestion, cleanup, aggregation, current-record selection, business rules, and a full-replacement load into one imperative object. The migrated fact is named `fct_order_revenue` because the available inputs calculate revenue after discounts, not profit after costs.

## Who this is for

This repository is for analytics engineers, data engineers, and dbt practitioners practicing source modeling, model grain, testing, lineage, and stored-procedure parity validation.

You should be comfortable with `source()`, `ref()`, dbt models, and tests. The workshop provides the legacy implementation and migration plan without assuming prior knowledge of the Merlin & Co. business domain.

## What you will build

`fct_order_revenue` has exactly one row per `order_id`. It provides cleaned order attributes, customer and shop context, latest recorded guild membership, item and payment rollups, revenue measures, and payment-state logic.

```text
raw warehouse sources
├── RAW_ORDERS
├── RAW_ORDER_ITEMS
├── RAW_PAYMENTS
├── RAW_CUSTOMERS
├── RAW_GUILD_MEMBERSHIPS
└── RAW_SHOPS

staging
├── stg_orders
├── stg_order_items
├── stg_payments
├── stg_customers
├── stg_guild_memberships
└── stg_shops

intermediate
├── int_order_item_rollup
├── int_payments_rollup
└── int_memberships_current

mart
├── fct_order_revenue
└── legacy_fct_order_profitability  [disabled compatibility view]
```

## How to use this repository

1. Read `analyses/legacy_sp_load_order_profitability.sql` and `analyses/legacy_sp_load_order_profitability_migration_plan.md`.
2. Use the guided prompts in `analyses/Cheatsheet/dbt_order_profitability_workshop_cheatsheet.md` if needed.
3. Use `models/staging/_merlinco_sources.yml` as the documented entry point for raw warehouse tables. Downstream models use `source()` for those tables and `ref()` between dbt models.
4. Build and test models incrementally, then validate the full fact lineage.
5. Run `analyses/compare_legacy_order_profitability_to_order_revenue.sql` before cutover.

## Key business rules

Until parity is approved, the migration retains these legacy behaviors:

- Orders with null `order_id` are excluded and monitored.
- Copper converts to gold by dividing by `100.0`; precision hardening is deferred until after parity.
- Only successful payment attempts contribute to paid amounts.
- `latest_paid_at` is the latest timestamp across all payment attempts, including unsuccessful attempts.
- Latest recorded guild membership is selected by `valid_to`, then `valid_from`, then `membership_id`; it is not an as-of-order join.
- Missing item and payment rollups preserve the procedure's null behavior.
- `payment_state` is `paid` when any payment succeeds, `cancelled` for an unpaid cancelled order, and `unpaid` otherwise.
- Missing customer and shop records do not remove orders.
- `is_home_region_order` is true only when normalized customer and shop regions match.
- `loaded_at` is a build timestamp and is excluded from parity comparisons.

The full model contracts, test policy, cutover, and rollback requirements are in `analyses/legacy_sp_load_order_profitability_migration_plan.md`.

## Maintenance expectations

- Keep raw inputs declared in `models/staging/_merlinco_sources.yml`.
- Keep each model's stated grain stable; update SQL, YAML, tests, and migration documentation together when semantics change.
- Add high-value tests for keys, joins, and consequential business rules.
- Validate SQL changes with the narrowest meaningful `dbt build --select +<model>+` selector.
- Preserve legacy behavior until parity establishes and documents an intentional difference.
- Do not edit generated or vendored content under `target/`, `logs/`, or `dbt_packages/`.

## Support

This workshop project is provided as-is without an SLA or ongoing maintenance commitment. Validate source locations, access controls, model logic, tests, and deployment procedures before adapting it to production.

## Repository layout

```text
.
├── analyses/
│   ├── Cheatsheet/
│   ├── compare_legacy_order_profitability_to_order_revenue.sql
│   ├── legacy_sp_load_order_profitability.sql
│   └── legacy_sp_load_order_profitability_migration_plan.md
├── models/
│   ├── staging/
│   ├── intermediate/
│   └── marts/
├── tests/
├── macros/
├── seeds/
├── snapshots/
└── dbt_project.yml
```

## Useful commands

```bash
# Validate project and YAML structure
dbt parse --no-partial-parse

# List current project models
dbt ls --resource-type model

# Build and test the complete revenue lineage
dbt build --select +fct_order_revenue+

# Preview development output
dbt show --select fct_order_revenue --limit 20

# Preview audit_helper classifications and status counts
dbt show --select path:analyses/compare_legacy_order_profitability_to_order_revenue.sql --limit 100
```

The compatibility view is disabled by default. Enable it only during approved cutover with `enable_order_revenue_compatibility_view: true`, after backing up or renaming the physical legacy table.

## Definition of done

The migration is complete when:

- all six raw inputs are documented dbt sources;
- staging models preserve source grain and own cleanup logic;
- intermediate models enforce order or customer grain;
- `fct_order_revenue` has exactly one row per `order_id`;
- blocking tests pass and warning results are reviewed;
- all business columns match the legacy output with `loaded_at` excluded;
- the compatibility view has been introduced through a reversible cutover;
- at least seven days and three successful production runs complete with healthy parity, warnings, freshness, and consumers; and
- the legacy procedure has no remaining direct dependencies before retirement.



