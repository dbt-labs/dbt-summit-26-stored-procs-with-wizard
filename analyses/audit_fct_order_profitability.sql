-- Parity audit: legacy stored-procedure output vs. dbt fct_order_profitability.
--
-- Legacy relation (verified to exist):
--   DBT_LEARN.DBT_WORKSHOP_JJOHNSON_AB4876.legacy_fct_order_profitability
-- dbt relation: ref('fct_order_profitability')
--
-- loaded_at is intentionally excluded: it is execution-time metadata
-- (current_timestamp()) and can never match between two separate runs.
--
-- Preview with:
--   dbt show --select path:analyses/audit_fct_order_profitability.sql --favor-state --limit 50

{% set audit_columns = [
    'order_id',
    'customer_id',
    'customer_name',
    'customer_email',
    'home_region',
    'favored_discipline',
    'guild_id',
    'guild_tier',
    'shop_id',
    'shop_name',
    'shop_city',
    'shop_region',
    'ordered_at',
    'ordered_date',
    'order_status',
    'order_channel',
    'item_quantity',
    'line_count',
    'distinct_potions',
    'gross_revenue_copper',
    'gross_revenue_gold',
    'discount_copper',
    'discount_gold',
    'net_revenue_copper',
    'net_revenue_gold',
    'paid_amount_copper',
    'paid_amount_gold',
    'latest_paid_at',
    'payment_attempt_count',
    'payment_state',
    'is_home_region_order'
] %}

{% set column_list = audit_columns | join(",\n    ") %}

{% set a_query %}
select
    {{ column_list }}
from DBT_LEARN.DBT_WORKSHOP_JJOHNSON_AB4876.legacy_fct_order_profitability
{% endset %}

{% set b_query %}
select
    {{ column_list }}
from {{ ref('fct_order_profitability') }}
{% endset %}

{{ audit_helper.compare_and_classify_query_results(
    a_query=a_query,
    b_query=b_query,
    primary_key_columns=['order_id'],
    columns=audit_columns
) }}
