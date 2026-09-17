{{ config(materialized='table') }}

with orders as (

    select
        order_id,
        customer_id,
        shop_id,
        ordered_at,
        order_status,
        order_channel,
        discount_dollars
    from {{ ref('stg_orders') }}

),

customers as (

    select
        customer_id,
        full_name,
        email,
        case
            when home_region = 'NR' then 'Northern Reaches'
            else initcap(home_region)
        end as home_region,
        favored_discipline
    from {{ ref('stg_customers') }}

),

shops as (

    select
        shop_id,
        shop_name,
        city,
        initcap(shop_region) as shop_region
    from {{ ref('stg_shops') }}

),

order_items as (

    select
        order_id,
        item_quantity,
        line_count,
        distinct_potions,
        gross_revenue_dollars
    from {{ ref('int_order_item_rollup') }}

),

payments as (

    select
        order_id,
        paid_amount_dollars,
        latest_paid_at,
        has_successful_payment,
        payment_attempt_count
    from {{ ref('int_payments_rollup') }}

),

memberships as (

    select
        customer_id,
        guild_id,
        guild_tier
    from {{ ref('int_memberships_current') }}

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
        i.gross_revenue_dollars as gross_revenue,
        coalesce(o.discount_dollars, 0) as discount,
        i.gross_revenue_dollars - coalesce(o.discount_dollars, 0) as net_revenue,
        p.paid_amount_dollars as paid_amount,
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
        end as is_home_region_order
    from orders o
    left join customers c
        on o.customer_id = c.customer_id
    left join memberships m
        on o.customer_id = m.customer_id
    left join shops s
        on o.shop_id = s.shop_id
    left join order_items i
        on o.order_id = i.order_id
    left join payments p
        on o.order_id = p.order_id

)

select * from final
