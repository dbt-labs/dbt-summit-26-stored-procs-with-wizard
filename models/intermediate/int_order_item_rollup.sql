with order_items as (

    select *
    from {{ ref('stg_order_items') }}

),

aggregated as (

    select
        order_id,
        sum(quantity) as item_quantity,
        sum(quantity * unit_price_copper) as gross_revenue_copper,
        sum((quantity * unit_price_copper) / 100.0) as gross_revenue_gold,
        count(*) as line_count,
        count(distinct potion_sku) as distinct_potions
    from order_items
    group by order_id

)

select *
from aggregated
