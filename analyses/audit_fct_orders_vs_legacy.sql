{#-
    Parity check: fct_orders (dbt) vs. legacy_fct_order_profitability (stored procedure).
    Compares only business columns; excludes loaded_at because it is execution-time metadata.
-#}

{% set legacy_query %}
    select
        order_id,
        customer_id,
        customer_name,
        customer_email,
        home_region,
        favored_discipline,
        guild_id,
        guild_tier,
        shop_id,
        shop_name,
        shop_city,
        shop_region,
        ordered_at,
        ordered_date,
        order_status,
        order_channel,
        item_quantity,
        line_count,
        distinct_potions,
        gross_revenue_gold as gross_revenue,
        discount_gold as discount,
        net_revenue_gold as net_revenue,
        paid_amount_gold as paid_amount,
        latest_paid_at,
        payment_attempt_count,
        payment_state,
        is_home_region_order
    from DBT_LEARN.DBT_WORKSHOP_MTRAN_398CAF.legacy_fct_order_profitability
{% endset %}

{% set dbt_query %}
    select
        order_id,
        customer_id,
        customer_name,
        customer_email,
        home_region,
        favored_discipline,
        guild_id,
        guild_tier,
        shop_id,
        shop_name,
        shop_city,
        shop_region,
        ordered_at,
        ordered_date,
        order_status,
        order_channel,
        item_quantity,
        line_count,
        distinct_potions,
        gross_revenue,
        discount,
        net_revenue,
        paid_amount,
        latest_paid_at,
        payment_attempt_count,
        payment_state,
        is_home_region_order
    from {{ ref('fct_orders') }}
{% endset %}

{{ audit_helper.compare_and_classify_query_results(
    a_query=legacy_query,
    b_query=dbt_query,
    primary_key_columns=['order_id'],
    columns=[
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
        'gross_revenue',
        'discount',
        'net_revenue',
        'paid_amount',
        'latest_paid_at',
        'payment_attempt_count',
        'payment_state',
        'is_home_region_order'
    ],
    sample_limit=20
) }}
