{{ config(materialized='table') }}

with orders as (

    select * from {{ ref('stg_orders') }}

),

item_rollup as (

    select * from {{ ref('int_order_item_rollup') }}

),

payments_rollup as (

    select * from {{ ref('int_payments_rollup') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

),

memberships_current as (

    select * from {{ ref('int_memberships_current') }}

),

shops as (

    select * from {{ ref('stg_shops') }}

),

final as (

    select
        o.order_id,
        o.customer_id,
        c.full_name as customer_name,
        c.email as customer_email,
        c.home_region,
        c.favored_discipline,
        m.guild_id,
        m.guild_tier,
        o.shop_id,
        s.shop_name,
        s.city as shop_city,
        s.shop_region,
        o.ordered_at,
        cast(o.ordered_at as date) as ordered_date,
        o.order_status,
        o.order_channel,
        i.item_quantity,
        i.line_count,
        i.distinct_potions,
        i.gross_revenue_copper,
        i.gross_revenue_gold,
        o.discount_copper,
        o.discount_gold,
        i.gross_revenue_copper - o.discount_copper as net_revenue_copper,
        i.gross_revenue_gold - o.discount_gold as net_revenue_gold,
        p.paid_amount_copper,
        p.paid_amount_gold,
        p.latest_paid_at,
        p.payment_attempt_count,
        case
            when coalesce(p.has_successful_payment, 0) = 1 then 'paid'
            when o.order_status in ('cancelled', 'canceled') then 'cancelled'
            else 'unpaid'
        end as payment_state,
        case
            when c.home_region = s.shop_region then true
            else false
        end as is_home_region_order,
        current_timestamp() as loaded_at

    from orders o
    left join item_rollup i
        on o.order_id = i.order_id
    left join payments_rollup p
        on o.order_id = p.order_id
    left join customers c
        on o.customer_id = c.customer_id
    left join memberships_current m
        on o.customer_id = m.customer_id
    left join shops s
        on o.shop_id = s.shop_id

)

select * from final
