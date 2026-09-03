{{ config(materialized='table') }}

with orders as (

    select *
    from {{ ref('stg_orders') }}

),

order_items as (

    select *
    from {{ ref('int_order_item_rollup') }}

),

payments as (

    select *
    from {{ ref('int_payments_rollup') }}

),

customers as (

    select *
    from {{ ref('stg_customers') }}

),

memberships as (

    select *
    from {{ ref('int_memberships_current') }}

),

shops as (

    select *
    from {{ ref('stg_shops') }}

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        customers.full_name as customer_name,
        customers.email as customer_email,
        customers.home_region,
        customers.favored_discipline,
        memberships.guild_id,
        memberships.guild_tier,
        orders.shop_id,
        shops.shop_name,
        shops.city as shop_city,
        shops.shop_region,
        orders.ordered_at,
        cast(orders.ordered_at as date) as ordered_date,
        orders.order_status,
        orders.order_channel,
        order_items.item_quantity,
        order_items.line_count,
        order_items.distinct_potions,
        order_items.gross_revenue_copper,
        order_items.gross_revenue_gold,
        orders.discount_copper,
        orders.discount_gold,
        order_items.gross_revenue_copper - orders.discount_copper as net_revenue_copper,
        order_items.gross_revenue_gold - orders.discount_gold as net_revenue_gold,
        payments.paid_amount_copper,
        payments.paid_amount_gold,
        payments.latest_paid_at,
        payments.payment_attempt_count,
        case
            when coalesce(payments.has_successful_payment, 0) = 1 then 'paid'
            when orders.order_status in ('cancelled', 'canceled') then 'cancelled'
            else 'unpaid'
        end as payment_state,
        case
            when customers.home_region = shops.shop_region then true
            else false
        end as is_home_region_order,
        current_timestamp() as loaded_at
    from orders
    left join order_items
        on orders.order_id = order_items.order_id
    left join payments
        on orders.order_id = payments.order_id
    left join customers
        on orders.customer_id = customers.customer_id
    left join memberships
        on orders.customer_id = memberships.customer_id
    left join shops
        on orders.shop_id = shops.shop_id

)

select *
from final
