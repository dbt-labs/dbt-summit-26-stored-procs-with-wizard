# Migration plan: `sp_load_order_profitability`

## Decision and migration posture

Use an **exact-parity-first** migration. The first dbt release will preserve the stored procedure's output grain, columns, null handling, membership selection, payment treatment, and financial calculations. Business-semantic improvements will be evaluated only after the dbt output matches the legacy output and the cutover is stable.

Assumptions used by this plan:

- The three layers are **staging → intermediate → mart**.
- Raw inputs remain existing Snowflake tables declared as dbt sources.
- The initial mart is rebuilt as a table rather than implemented incrementally.
- Configuration covers environment-specific deployment concerns. Business rules remain explicit in model SQL and tests.
- The output remains one row per non-null `order_id` and preserves the legacy business columns.
- `loaded_at` remains in the dbt model but is excluded from value-parity comparisons.

## Procedure goal and current behavior

The procedure rebuilds an order-level analytical table from six operational inputs. It cleans source values, aggregates one-to-many order children, selects one latest guild membership per customer, enriches each order with customer and shop attributes, calculates revenue and payment fields, and replaces the target contents.

Despite the `profitability` name, the procedure does not calculate cost, gross profit, or margin. It produces order revenue, discount, payment, and customer/shop context. Preserve the established name for parity if consumers depend on it; reassess naming or add true profitability measures only after cutover.

### Raw inputs

| Source | Native grain | Role |
| --- | --- | --- |
| `RAW_ORDERS` | One row per `order_id` | Order header, status, channel, timestamp, and discount |
| `RAW_ORDER_ITEMS` | One row per `order_item_id` | Quantity, potion, and order-line revenue |
| `RAW_PAYMENTS` | One row per `payment_id` | Payment attempts, statuses, amounts, and timestamps |
| `RAW_CUSTOMERS` | One row per `customer_id` | Customer identity, region, signup, and discipline |
| `RAW_GUILD_MEMBERSHIPS` | One row per `membership_id` | Historical customer membership intervals |
| `RAW_SHOPS` | One row per `shop_id` | Shop identity, city, region, and opening date |

### Legacy rules to preserve in phase one

- Exclude orders with a null `order_id`.
- Normalize order/payment statuses and channels with `lower(trim(...))`.
- Normalize customer and shop regions as implemented by the procedure.
- Parse source strings with Snowflake `try_to_*` functions.
- Convert null or invalid monetary and quantity inputs to zero where the procedure currently does so.
- Convert copper to gold by dividing by `100.0`.
- Sum only successful payment attempts into paid amount.
- Ignore refunds when calculating paid amount and classify an order as paid when any successful attempt exists.
- Set `latest_paid_at` from the latest timestamp across all payment attempts, regardless of status.
- Select the latest known membership per customer by `valid_to`, then `valid_from`, then `membership_id`; attach it to all orders for that customer.
- Leave payment rollup columns null when an order has no payment rows.
- Set payment state to `paid`, then `cancelled`/`canceled`, otherwise `unpaid`, in that precedence order.
- Set `is_home_region_order` to true only when normalized customer and shop regions are equal.
- Generate `loaded_at` at model execution time.

## Target DAG

```text
sources
├── raw_orders ────────────────> stg_orders ───────────────────────────────┐
├── raw_order_items ───────────> stg_order_items ─> int_order_item_rollup ─┤
├── raw_payments ──────────────> stg_payments ────> int_payments_rollup ───┤
├── raw_customers ─────────────> stg_customers ─────────────────────────────┤
├── raw_guild_memberships ─────> stg_guild_memberships                     │
│                                                  └> int_memberships_current
└── raw_shops ─────────────────> stg_shops ─────────────────────────────────┤
                                                                              └> fct_order_profitability
```

## Layer design

### Layer 1: staging

Staging models provide one typed, consistently named interface per raw source. They preserve source grain and contain only source-specific cleanup.

| Model | Grain | Responsibilities | Initial materialization |
| --- | --- | --- | --- |
| `stg_orders` | One row per non-null `order_id` | Parse `ordered_at`; normalize status/channel; type discount; derive `discount_gold`; preserve customer/shop keys | View |
| `stg_order_items` | One row per `order_item_id` | Type quantity and unit price; preserve order and potion keys | View |
| `stg_payments` | One row per `payment_id` | Normalize status; type amount; derive gold amount; parse `paid_at`; preserve order key | View |
| `stg_customers` | One row per `customer_id` | Normalize email, home region, and discipline; parse signup date and birth year | View |
| `stg_guild_memberships` | One row per `membership_id` | Normalize tier; parse validity dates; preserve tie-break columns | View |
| `stg_shops` | One row per `shop_id` | Normalize region; parse opening date | View |

Implementation rules:

- Use `source('merlinco_apothecaries', ...)` for all raw inputs.
- Use explicit column lists and source-oriented CTEs.
- Keep aggregation and cross-entity business logic out of staging.
- Preserve identifiers required for deterministic tie-breaking and relationship tests.

### Layer 2: intermediate

Intermediate models own reusable grain changes and consequential business rules.

| Model | Grain | Responsibilities | Initial materialization |
| --- | --- | --- | --- |
| `int_order_item_rollup` | One row per `order_id` with items | Sum quantity and gross revenue; count lines and distinct potions | View or ephemeral, following runtime evidence |
| `int_payments_rollup` | One row per `order_id` with payments | Sum successful amounts; capture latest attempt timestamp; flag successful payment; count attempts | View or ephemeral, following runtime evidence |
| `int_memberships_current` | At most one row per `customer_id` | Apply the exact legacy latest-membership ordering rule | View |

Keep these models independently testable. Default to views for observability during migration; consider ephemeral materialization only after parity and performance validation.

### Layer 3: mart

`fct_order_profitability` has one row per `stg_orders.order_id` and left joins every enrichment so the order population remains the driving set.

Responsibilities:

- Preserve the legacy output column set and order-level grain.
- Join item and payment rollups by `order_id`.
- Join customers and current memberships by `customer_id`.
- Join shops by `shop_id`.
- Calculate net revenue, payment state, home-region flag, and `loaded_at`.
- Materialize as a table for an atomic dbt-managed replacement.

Do not make the mart incremental in phase one. Changes to items, payments, customer attributes, shop attributes, or memberships can restate historical orders, and the current sources do not expose a confirmed cross-source change watermark.

## Configuration design

Configure deployment concerns while keeping parity-sensitive business rules visible in SQL.

### Configure

- Source database and schema through environment-aware dbt configuration, preserving `RAW.MERLINCO_APOTHECARIES` as the current default only if required by the target environments.
- Layer-specific target schemas through `dbt_project.yml` or the platform environment configuration.
- Folder-level materializations: staging views, intermediate views, mart tables.
- Tags and model groups/owners if the project has an established convention.
- Warehouse, role, threads, schedules, and target database at the dbt environment/job level.

### Do not parameterize initially

- Successful payment status.
- Cancelled status values.
- Copper-to-gold divisor.
- Region normalization.
- Membership ordering.
- Null handling.

Those values define the model's business contract. If future domains require different rules, prefer governed reference data or separate model versions over runtime variables that make results difficult to reproduce.

## Data contracts and tests

### Source and staging checks

- `not_null` and `unique` on source/staging primary identifiers.
- Relationships from order items and payments to orders, with severity agreed from observed orphan policy.
- Relationships from orders to customers and shops if orphaned dimensional keys are invalid.
- Accepted values or anomaly monitors for normalized statuses after confirming the complete domain.
- Warning-level checks for source values that fail `try_to_number`, `try_to_date`, or `try_to_timestamp_ntz` while remaining non-null.

### Intermediate checks

- `unique` and `not_null` on both order-rollup `order_id` columns.
- `unique` and `not_null` on `int_memberships_current.customer_id`.
- A unit test for membership tie-breaking across open-ended, closed, equal-date, and multiple-membership cases.
- A unit test for payment precedence covering success, failure, refund, no successful attempt, and mixed attempts.
- Reconciliation checks between staged child rows and rollup totals/counts.

### Mart checks

- `unique` and `not_null` on `order_id`.
- Row count equals `stg_orders` row count.
- Accepted values for `payment_state`: `paid`, `cancelled`, `unpaid`.
- Relationships to staging customer and shop keys if the source-domain contract requires complete dimensions.
- Expression checks for copper/gold conversion and net-revenue arithmetic using agreed numeric tolerance.
- A targeted check that every order has an item rollup, because the current profile shows none missing.
- A targeted check that payment-null rows follow the preserved legacy classification.

Avoid asserting that paid or net amounts are universally nonnegative until refunds, credits, and over-discounting policies are confirmed.

## Implementation sequence

1. **Clean project entry points**
   - Keep the source declaration under `models/staging/_merlinco_sources.yml`.
   - Remove or clearly archive the duplicate `staging/_merlinco_sources.yml`, which is outside configured `model-paths`.
   - Correct documentation that describes the raw warehouse inputs as seeds.

2. **Confirm deployment configuration**
   - Confirm environment-specific source and target locations.
   - Confirm the target relation name, ownership, grants, and consumer-facing schema.
   - Add folder-level layer configurations and tags.

3. **Build staging models**
   - Implement one source-preserving model per raw table.
   - Add model/column documentation and key tests.
   - Validate each staging model with narrow `dbt build --select +<model>+` runs.

4. **Build intermediate models**
   - Implement order-item and payment rollups.
   - Implement exact legacy membership selection.
   - Add grain tests and focused unit tests for payment and membership rules.

5. **Build the mart**
   - Recreate the legacy joins, calculations, output columns, and null behavior.
   - Materialize as a table and build the complete lineage with `dbt build --select +fct_order_profitability+`.

6. **Establish parity evidence**
   - Identify or create a stable legacy baseline from the actual procedure output.
   - Compare row presence by `order_id`, schema/types, and every business column.
   - Exclude `loaded_at` from value comparison.
   - Classify mismatches as row-only-left, row-only-right, or changed values, then trace each mismatch to the first divergent layer.
   - Require zero unexplained differences before cutover.

7. **Prepare and execute cutover**
   - Inventory downstream consumers and required grants.
   - Run the dbt DAG and legacy procedure in parallel for an agreed observation period.
   - Switch consumers through the agreed stable relation name or a temporary compatibility view.
   - Retain the procedure and last known-good legacy table during the rollback window.

8. **Stabilize and retire**
   - Monitor row counts, freshness, uniqueness, null rates, revenue totals, payment-state distribution, and runtime.
   - Retire the procedure only after parity sign-off, consumer confirmation, stable scheduled runs, and expiration of the rollback window.

9. **Evaluate semantic improvements separately**
   - Compare latest membership with as-of-order membership.
   - Define refund-adjusted payment/revenue measures and states.
   - Decide whether missing payment measures should be zero-filled.
   - Rename `latest_paid_at` or restrict it to successful attempts.
   - Define explicit numeric precision and rounding.
   - Decide whether customer name/email belong in this mart.
   - Reassess the `profitability` name or add validated cost/profit measures.

Treat these as intentional contract changes with their own impact analysis, tests, parity expectations, and consumer migration.

## Validation and acceptance criteria

The migration is ready for cutover when:

- all six raw inputs resolve through dbt sources;
- every staging model preserves its declared source grain;
- every intermediate model passes its grain and business-rule tests;
- the mart has exactly one row per non-null source order;
- the complete DAG builds successfully in the deployment environment;
- schema and business-column comparisons show no unexplained legacy/dbt differences;
- source-to-target permissions, ownership, scheduling, and grants are confirmed;
- downstream consumers and rollback steps are documented; and
- the observation period completes without freshness, quality, or runtime regressions.

## Open decisions and required owners

| Decision | Why it matters | Required owner |
| --- | --- | --- |
| Actual legacy output relation and procedure invocation | Blocks executable parity comparison and scheduler cutover | Data platform / job owner |
| Final consumer-facing relation name | Determines compatibility view or direct replacement strategy | Analytics owner / consumers |
| Source and target locations by environment | Defines deployable dbt configuration | Data platform owner |
| Schedule, SLA, and observation/rollback windows | Defines operational acceptance | Pipeline owner |
| Customer name/email policy | Determines whether PII can remain in the mart | Data governance / security |
| Numeric precision and rounding contract | Prevents future financial representation drift | Finance / analytics owner |
| Post-parity membership semantics | Changes 12,279 profiled order assignments | Business owner |
| Post-parity refund semantics | Changes payment treatment for 3,003 profiled orders | Finance / business owner |
| Missing-payment measure semantics | Affects 1,315 profiled cancelled orders | Analytics owner |

## Profile evidence captured during planning

- `RAW_ORDERS`: 75,000 rows; no null or duplicate `order_id` values.
- `RAW_ORDER_ITEMS`: 252,537 rows; no null or duplicate `order_item_id` values; every order currently has items.
- `RAW_PAYMENTS`: 85,948 rows; no null or duplicate `payment_id` values.
- `RAW_GUILD_MEMBERSHIPS`: 14,550 rows for 13,055 customers; 1,495 rows represent membership history beyond one row per customer.
- 1,315 orders have no payment rows; all are currently cancelled.
- 3,003 orders have both successful and refunded payment attempts and remain fully paid under legacy logic.
- Latest-membership and as-of-order membership assignments differ for 12,279 orders.
- No negative net-revenue orders were observed in the current profile.
- No account-visible `LEGACY_FCT_ORDER_PROFITABILITY` table was found during planning.
