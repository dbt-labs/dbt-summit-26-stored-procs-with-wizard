{% set columns_to_compare = [
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

{% set legacy_query %}
    {{ legacy_order_profitability_business_query() }}
{% endset %}

{% set dbt_query %}
    select {{ columns_to_compare | join(', ') }}
    from {{ ref('fct_order_revenue') }}
{% endset %}

{{
    audit_helper.compare_and_classify_query_results(
        a_query=legacy_query,
        b_query=dbt_query,
        primary_key_columns=['order_id'],
        columns=columns_to_compare,
        sample_limit=20
    )
}}
