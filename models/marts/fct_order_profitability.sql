{{ config(materialized='table') }}

with orders as (

    select *
    from {{ ref('stg_orders') }}

),

order_item_rollup as (

    select *
    from {{ ref('int_order_item_rollup') }}

),

payments_rollup as (

    select *
    from {{ ref('int_payments_rollup') }}

),

customers as (

    select *
    from {{ ref('stg_customers') }}

),

memberships_current as (

    select *
    from {{ ref('int_memberships_current') }}

),

shops as (

    select *
    from {{ ref('stg_shops') }}

)

select
    orders.order_id,
    orders.customer_id,
    customers.full_name as customer_name,
    customers.email as customer_email,
    customers.home_region,
    customers.favored_discipline,
    memberships_current.guild_id,
    memberships_current.guild_tier,
    orders.shop_id,
    shops.shop_name,
    shops.city as shop_city,
    shops.shop_region,
    orders.ordered_at,
    cast(orders.ordered_at as date) as ordered_date,
    orders.order_status,
    orders.order_channel,
    order_item_rollup.item_quantity,
    order_item_rollup.line_count,
    order_item_rollup.distinct_potions,
    order_item_rollup.gross_revenue_copper,
    order_item_rollup.gross_revenue_gold,
    orders.discount_copper,
    orders.discount_gold,
    order_item_rollup.gross_revenue_copper - orders.discount_copper as net_revenue_copper,
    order_item_rollup.gross_revenue_gold - orders.discount_gold as net_revenue_gold,
    payments_rollup.paid_amount_copper,
    payments_rollup.paid_amount_gold,
    payments_rollup.latest_paid_at,
    payments_rollup.payment_attempt_count,
    case
        when coalesce(payments_rollup.has_successful_payment, 0) = 1 then 'paid'
        when orders.order_status in ('cancelled', 'canceled') then 'cancelled'
        else 'unpaid'
    end as payment_state,
    case
        when customers.home_region = shops.shop_region then true
        else false
    end as is_home_region_order,
    current_timestamp() as loaded_at
from orders
left join order_item_rollup
    on orders.order_id = order_item_rollup.order_id
left join payments_rollup
    on orders.order_id = payments_rollup.order_id
left join customers
    on orders.customer_id = customers.customer_id
left join memberships_current
    on orders.customer_id = memberships_current.customer_id
left join shops
    on orders.shop_id = shops.shop_id
