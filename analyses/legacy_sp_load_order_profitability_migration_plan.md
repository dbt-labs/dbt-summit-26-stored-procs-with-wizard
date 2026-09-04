# Migration plan: `sp_load_order_profitability`


## Showing username in workshop 

dbt show --inline "select current_user()" --limit 1

## Recommended target DAG

```text
raw seeds
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

## Mapping from stored procedure to dbt models

### 1. `tmp_orders_clean` → `stg_orders`

**Current procedure behavior**
- reads `raw_orders`
- parses `ordered_at`
- normalizes `status` and `channel`
- converts `discount_copper` to numeric
- derives `discount_gold`
- filters out null `order_id`

**dbt model responsibility**
`stg_orders` should own all column cleanup for the raw order table.


### 2. `tmp_order_item_rollup` → `int_order_item_rollup`

**Current procedure behavior**
- aggregates `raw_order_items` to order grain
- calculates quantity, gross revenue, line count, and distinct potions

**dbt model responsibility**
Keep `stg_order_items` at line-item grain, and move the rollup to a separate intermediate model.

---

### 3. `tmp_payments_rollup` → `int_payments_rollup`

**Current procedure behavior**
- aggregates payment attempts to order grain
- sums successful payment amounts only
- captures latest paid timestamp
- flags whether the order has any successful payment

**dbt model responsibility**
Keep raw payment cleanup in `stg_payments`, and centralize business rollup logic in an intermediate model.

---

### 4. `tmp_membership_current` → `int_memberships_current`

**Current procedure behavior**
- dedupes membership history to a single current record per customer
- picks the latest valid membership using `row_number()`

**dbt model responsibility**
This is classic intermediate logic and should be isolated because it has a business rule worth testing independently.


---

### 5. `tmp_customer_clean` → `stg_customers`

**Current procedure behavior**
- normalizes email case
- standardizes `home_region`
- parses sign-up date and birth year
- normalizes discipline casing

**dbt model responsibility**
All customer cleanup belongs in staging.


---

### 6. `tmp_shop_clean` → `stg_shops`

**Current procedure behavior**
- standardizes region formatting
- parses `opened_at`

**dbt model responsibility**
This belongs in staging with simple type cleanup and naming alignment.


### 7. `tmp_fct_order_profitability` + final `delete/insert` → `fct_order_profitability`

**Current procedure behavior**
- joins all cleaned and rolled-up datasets
- derives net revenue and payment state
- flags home-region loyalty
- writes a full replacement of the mart table

**dbt model responsibility**
This becomes a fact model that depends on staging and intermediate models through `ref()`.
