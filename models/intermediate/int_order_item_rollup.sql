with order_items as (

    select *
    from {{ ref('stg_order_items') }}

)

select
    order_id,
    sum(quantity) as item_quantity,
    sum(quantity * unit_price) as gross_revenue
from order_items
group by order_id
