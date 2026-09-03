# dbt Summit 2026: Migrating Stored Procedures with dbt Wizard

## What this repository is

This is a hands-on dbt workshop repository for migrating the Snowflake stored procedure `sp_load_order_profitability` into a tested, documented dbt DAG using dbt Wizard.

The scenario uses Merlin & Co. Apothecaries operational data. The legacy procedure combines raw ingestion, cleanup, aggregation, current-record selection, business rules, and a full-replacement load into one imperative object. During the workshop, you will separate those responsibilities into reusable dbt models and produce an order-profitability fact table with one row per order.

## Who this is for

This repository is for analytics engineers, data engineers, and dbt practitioners who want a practical migration exercise from legacy Snowflake stored procedures to modular dbt models. It is designed for dbt Summit workshop participants and is equally useful for anyone practicing source modeling, model grain, testing, lineage, and procedure-parity validation.

You should be comfortable reading SQL and basic dbt concepts such as `source()`, `ref()`, models, and tests. The workshop provides the legacy implementation and a guided migration plan; it does not assume prior knowledge of the Merlin & Co. business domain.

## What you will build

The target model is `fct_order_profitability`, at a grain of one row per `order_id`. It will provide cleaned order attributes, customer and shop context, current guild membership, item and payment rollups, revenue measures, and payment-state logic.

The recommended DAG is:

```text
raw warehouse tables
├── raw_orders
├── raw_order_items
├── raw_payments
├── raw_customers
├── raw_guild_memberships
└── raw_shops

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
└── fct_order_profitability
```

## How to use this repository

### Prerequisites

- Access to a Snowflake target that can read the `RAW_WIZARD.MERLINCO_APOTHECARIES` raw schema.
- A configured dbt profile named `default`.
- dbt Fusion / dbt Platform with dbt Wizard enabled.
- Permission to create relations in your development target schema.

### Workshop sequence

1. Review `dbt_project.yml` for the configured project paths and profile. The project name is currently the starter value `my_new_project`; update it if your workshop environment requires a different package name.
2. Read the legacy implementation in `analyses/legacy_sp_load_order_profitability.sql` and the design in `analyses/legacy_sp_load_order_profitability_migration_plan.md`.
3. Follow the guided instructions during the workshop. If you are stuck, utilize the guided prompts in `analyses/dbt_order_profitability_workshop_cheatsheet.md`.
4. Use `models/staging/_merlinco_sources.yml` as the documented entry point for the raw warehouse tables. These inputs are warehouse tables, so downstream models should use `source()`, not `ref()`.
5. Build and test models incrementally as you add them, then validate the completed fact lineage:

```bash
dbt build --select +fct_order_profitability+
```

The starter `models/example/` models are included only as the default dbt scaffold. They intentionally contain a null key and their attached `not_null` test will fail until you remove, correct, or replace the example models.

### Workshop flow

1. **Understand the legacy procedure** — identify its raw inputs, temporary tables, output columns, grain, and business rules.
2. **Declare sources** — document the raw relations and add high-value source-key tests.
3. **Build staging models** — keep each source's native grain while cleaning types, casing, whitespace, and sentinel values.
4. **Build intermediate models** — aggregate line items and payments to order grain, and isolate current-membership selection.
5. **Build the fact** — join the cleaned and rolled-up models into `fct_order_profitability` at one row per `order_id`.
6. **Test the contracts** — cover primary keys, relationship assumptions, accepted payment states, and the membership tie-break rule.
7. **Validate parity** — compare the dbt fact output with the legacy procedure output before cutover.

## Key business rules to preserve

Until parity is agreed, the dbt migration should retain these legacy behaviors:

- Orders with a null `order_id` are excluded.
- Monetary values are stored in copper and converted to gold by dividing by `100.0`.
- Only successful payment attempts contribute to paid amounts.
- Current guild membership is selected per customer by latest `valid_to`, then `valid_from`, then `membership_id`.
- `payment_state` is `paid` when any successful payment exists, `cancelled` for cancelled orders without a successful payment, and `unpaid` otherwise.
- `is_home_region_order` is true when the customer's normalized home region matches the shop's normalized region.

The migration plan documents the proposed model-level ownership, grains, columns, and tests in detail: `analyses/legacy_sp_load_order_profitability_migration_plan.md`.

## Basic maintenance expectations

Treat this as a working dbt project, even when using it as a workshop exercise:

- Keep raw inputs declared and documented in `models/staging/_merlinco_sources.yml`; use `source()` for warehouse tables and `ref()` between dbt models.
- Keep each model's stated grain stable. If a change alters a model's grain, output contract, or business semantics, update its SQL, schema YAML, tests, and relevant workshop documentation together.
- Add concise model and column descriptions alongside new models in schema YAML, and add high-value tests for primary keys, relationships, and consequential business rules.
- Validate SQL changes with the narrowest meaningful `dbt build --select +<model>+` selector. Run `dbt parse` after source or schema-YAML changes.
- Preserve the legacy procedure's behavior until a parity comparison establishes and documents an intentional difference. Exclude execution-time metadata such as `loaded_at` from parity checks.
- Keep generated artifacts out of source changes: do not edit `target/`, `logs/`, or `dbt_packages/`.

## Support and maintenance expectations

This project is provided **as is** for workshop and learning purposes. It has no service-level agreement (SLA), guaranteed response time, uptime commitment, or ongoing maintenance obligation.

Use it as a reference and adapt it for your environment. Before relying on it for production workloads, validate the source locations, access controls, model logic, tests, and deployment process under your team's ownership.


## Repository layout

```text
.
├── analyses/
│   ├── legacy_sp_load_order_profitability.sql
│   ├── legacy_sp_load_order_profitability_migration_plan.md
│   └── dbt_order_profitability_workshop_cheatsheet.md
├── models/
│   ├── staging/
│   │   └── _merlinco_sources.yml
│   └── example/                         # default dbt starter models
├── macros/
├── seeds/
├── snapshots/
├── tests/
├── dbt_project.yml
└── README.md
```

As you progress, add the staging, intermediate, and mart models under `models/`, with their model and column documentation in colocated schema YAML files.

## Useful commands

Use narrow selectors while developing, then build the full fact lineage once the dependencies are in place:

```bash
# Validate project and YAML structure
dbt parse

# List the current project models
dbt ls --resource-type model

# Build and test a model with its upstream dependencies
dbt build --select +stg_orders

# Build and test the full profitability DAG
dbt build --select +fct_order_profitability+

# Preview a development model's output
dbt show --select fct_order_profitability --limit 20
```

When performing a parity check against production state, use `--favor-state` so every `ref()` resolves consistently to the deferred production relation.

## Definition of done

The workshop migration is complete when:

- each raw input is declared as a documented dbt source;
- staging models preserve source grain and own cleanup logic;
- intermediate models enforce their stated order or customer grain;
- `fct_order_profitability` has exactly one row per `order_id`;
- key, relationship, and business-rule tests pass;
- the dbt fact output has been compared to the legacy procedure with execution-time metadata such as `loaded_at` excluded; and
- the legacy procedure can be retired through a reversible, monitored cutover plan.

## Showing username in workshop 

dbt show --inline "select current_user()" --limit 1

