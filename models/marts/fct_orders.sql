{{ config(materialized='table') }}

with orders as (

    select *
    from {{ ref('stg_orders') }}

),

customers as (

    select *
    from {{ ref('stg_customers') }}

),

order_items as (

    select *
    from {{ ref('int_order_item_rollup') }}

),

payments as (

    select *
    from {{ ref('int_payments_rollup') }}

)

select
    o.order_id,
    o.customer_id,
    c.customer_name,
    i.item_quantity,
    i.gross_revenue,
    o.discount,
    i.gross_revenue - o.discount as net_revenue,
    p.paid_amount,
    case
        when coalesce(p.has_successful_payment, 0) = 1 then 'paid'
        when o.order_status in ('cancelled', 'canceled') then 'cancelled'
        else 'unpaid'
    end as payment_state
from orders o
left join customers c
    on o.customer_id = c.customer_id
left join order_items i
    on o.order_id = i.order_id
left join payments p
    on o.order_id = p.order_id
