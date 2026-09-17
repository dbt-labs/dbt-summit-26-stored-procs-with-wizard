# Migration plan: `sp_load_order_profitability`

## Objective

Replace the imperative Snowflake procedure with a tested dbt DAG while preserving its business behavior through parity validation. The dbt fact is named `fct_order_revenue` because the available inputs calculate revenue after discounts, not profit after costs.

The legacy relation name remains available during cutover through a disabled-by-default dbt compatibility view named `legacy_fct_order_profitability`.

## Target DAG

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
└── legacy_fct_order_profitability  [compatibility view; disabled by default]
```

Raw warehouse relations are declared with `source()`. All dependencies between dbt models use `ref()`.

## Model responsibilities and grains

### Staging

- `stg_orders`: one row per non-null `order_id`; parses `ordered_at`, normalizes status/channel, parses discount copper, and derives discount gold. Raw null order IDs are filtered and monitored without blocking the build.
- `stg_order_items`: one row per `order_item_id`; parses quantity and unit price while retaining order and potion identifiers.
- `stg_payments`: one row per `payment_id`; normalizes method/status and parses amount and payment timestamp.
- `stg_customers`: one row per `customer_id`; normalizes email, region, signup date, birth year, and favored discipline.
- `stg_guild_memberships`: one row per `membership_id`; normalizes tier and parses validity dates. `membership_id` is retained for deterministic tie-breaking.
- `stg_shops`: one row per `shop_id`; normalizes region and parses opening date.

### Intermediate

- `int_order_item_rollup`: one row per `order_id`; calculates item quantity, gross revenue in copper/gold, line count, and distinct potion count.
- `int_payments_rollup`: one row per `order_id`; sums successful payments only, counts all attempts, flags any success, and records the latest timestamp across all attempts—including unsuccessful attempts—for legacy parity.
- `int_memberships_current`: one row per `customer_id`; selects the latest recorded membership by `valid_to` with open-ended records treated as `2999-12-31`, then `valid_from`, then `membership_id`, all descending.

The membership selection is latest-record semantics. It is not an as-of-order join and does not independently test whether a membership is active today.

### Mart

`fct_order_revenue` is a table with exactly one row per `order_id`. It preserves the procedure's left joins and complete output contract:

```text
order_id, customer_id, customer_name, customer_email, home_region,
favored_discipline, guild_id, guild_tier, shop_id, shop_name, shop_city,
shop_region, ordered_at, ordered_date, order_status, order_channel,
item_quantity, line_count, distinct_potions, gross_revenue_copper,
gross_revenue_gold, discount_copper, discount_gold, net_revenue_copper,
net_revenue_gold, paid_amount_copper, paid_amount_gold, latest_paid_at,
payment_attempt_count, payment_state, is_home_region_order, loaded_at
```

`loaded_at` is the dbt build timestamp and is excluded from parity comparisons.

## Legacy behavior retained for parity

- Orders with null `order_id` are excluded.
- Malformed or null order discounts become zero.
- Malformed or null line-item quantities and prices contribute zero inside item aggregates.
- Copper converts to gold by division by `100.0`, preserving the procedure's current inferred numeric behavior until a separate precision-hardening change.
- Orders without item rollups retain null item and revenue measures.
- Orders without payment attempts retain null payment measures and are classified as `unpaid` unless cancelled.
- Only successful payment attempts contribute to paid amounts.
- `payment_state` is `paid` when any payment succeeds, `cancelled` for an unpaid cancelled/canceled order, and `unpaid` otherwise.
- Missing customer or shop records do not remove orders because all enrichment joins remain left joins.
- `is_home_region_order` is true only when normalized customer and shop regions match; missing values produce false.
- Current customer, shop, and latest-membership attributes are applied to historical orders, matching the procedure.

## Data quality controls

Blocking tests:

- `unique` and `not_null` on staging entity keys.
- `unique` and `not_null` on each intermediate grain key.
- `unique` and `not_null` on `fct_order_revenue.order_id`.
- Accepted values of `paid`, `cancelled`, and `unpaid` for `payment_state`.
- A unit test proving open-ended membership selection and deterministic date/ID tie-breaking.

Warning-level controls:

- Raw orders with null `order_id`.
- Orders without an item rollup.
- Customer or shop foreign keys missing from staging.
- Negative net revenue until the business establishes whether it is invalid.

Payment nulls are allowed because an order may legitimately exist before any payment attempt.

## Parity validation

The account currently has no visible table or view named `legacy_fct_order_profitability`. The macro `legacy_order_profitability_business_query()` therefore renders the stored procedure's transformation logic directly from the six raw sources without executing its DDL or final delete/insert. This query is the legacy side of the parity audit.

`analyses/compare_legacy_order_profitability_to_order_revenue.sql` uses `audit_helper.compare_and_classify_query_results` with:

- the rendered legacy procedure query as side A;
- `fct_order_revenue` as side B;
- `order_id` as the primary key;
- all 31 business columns explicitly listed;
- `loaded_at` excluded because it is execution-time metadata.

The analysis returns sampled rows with package classifications:

- `identical`: the complete business row exists on both sides;
- `added`: the row exists only in dbt (side B);
- `removed`: the row exists only in the legacy query (side A);
- `modified`: the same primary key has different business values.

`tests/assert_order_revenue_matches_legacy.sql` runs the same comparison without a sample limit and returns every non-identical row, making parity a blocking dbt data test.

Build and test the complete lineage, including parity:

```text
dbt build --select +fct_order_revenue+
```

Preview sampled classifications and aggregate status counts with:

```text
dbt show --select path:analyses/compare_legacy_order_profitability_to_order_revenue.sql --limit 100
```

The validated development result contains 75,000 identical order keys and no added, removed, or modified records. Investigate any future difference at the first divergent staging or intermediate model; do not change transformation logic only to suppress unexplained mismatches.


## Cutover and rollback

1. Deploy `fct_order_revenue` to the configured production target database/schema.
2. Run the legacy procedure and dbt build against the same source snapshot or a controlled time window.
3. Require zero unexplained parity differences and successful blocking tests.
4. Confirm the production dbt role can create or replace the legacy relation in the configured target schema.
5. Back up or rename the physical legacy table using an approved Snowflake change before enabling the view.
6. Enable the dbt-managed compatibility view with `enable_order_revenue_compatibility_view: true`; it exposes `fct_order_revenue` as `legacy_fct_order_profitability`.
7. Observe at least seven days and three successful production runs. Monitor parity, model/test status, warning counts, row counts, freshness, and downstream consumer health.
8. Retire the procedure only after the observation gate passes and ownership confirms no direct procedure dependency remains.

Rollback disables/removes the compatibility view, restores the backed-up legacy table under its original name, and resumes the procedure. Keep the legacy procedure and backup relation available through the observation window.

## Operational prerequisites

- The production job must build `+fct_order_revenue+` and run its attached tests.
- The currently configured production job uses `dbt build` but has no active trigger; schedule or manually trigger at least three observed runs before retirement.
- Upstream raw tables must be available before the dbt job starts.
- The production dbt role needs read access to raw sources and create/replace privileges in the configured target schema.
- Numeric precision hardening and as-of-order membership are explicitly deferred follow-up changes requiring their own parity and consumer-impact review.
