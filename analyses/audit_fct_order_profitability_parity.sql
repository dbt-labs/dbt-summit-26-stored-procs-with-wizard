{#
    Parity preview: compares the dbt `fct_order_profitability` model against the legacy
    `sp_load_order_profitability` procedure's output relation, `legacy_fct_order_profitability`.

    - Excludes `loaded_at` from the comparison: it's execution-time metadata (current_timestamp()
      at build/run time) and will never match between the two independently-run pipelines.
    - Run as a preview only: `dbt show --favor-state --select path:analyses/audit_fct_order_profitability_parity.sql --limit 50`
#}

{% set comparison_columns = [
    "order_id",
    "customer_id",
    "customer_name",
    "customer_email",
    "home_region",
    "favored_discipline",
    "guild_id",
    "guild_tier",
    "shop_id",
    "shop_name",
    "shop_city",
    "shop_region",
    "ordered_at",
    "ordered_date",
    "order_status",
    "order_channel",
    "item_quantity",
    "line_count",
    "distinct_potions",
    "gross_revenue_copper",
    "gross_revenue_gold",
    "discount_copper",
    "discount_gold",
    "net_revenue_copper",
    "net_revenue_gold",
    "paid_amount_copper",
    "paid_amount_gold",
    "latest_paid_at",
    "payment_attempt_count",
    "payment_state",
    "is_home_region_order"
] %}

{% set dbt_relation_query %}
    select * from {{ ref('fct_order_profitability') }}
{% endset %}

{% set legacy_relation_query %}
    select * from DBT_LEARN.DBT_WORKSHOP_CMOWBRAY_094C7F.legacy_fct_order_profitability
{% endset %}

{{ audit_helper.compare_and_classify_query_results(
    a_query=dbt_relation_query,
    b_query=legacy_relation_query,
    primary_key_columns=["order_id"],
    columns=comparison_columns,
    sample_limit=50
) }}
