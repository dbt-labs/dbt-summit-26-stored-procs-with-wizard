with order_items as (

<<<<<<< HEAD
    select *
    from {{ ref('stg_order_items') }}

),

rolled_up as (

    select
        order_id,
        sum(coalesce(quantity, 0)) as item_quantity,
        sum(coalesce(quantity, 0) * coalesce(unit_price_copper, 0)) as gross_revenue_copper,
        sum((coalesce(quantity, 0) * coalesce(unit_price_copper, 0)) / 100.0) as gross_revenue_gold,
        count(*) as line_count,
        count(distinct potion_sku) as distinct_potions
    from order_items
=======
    select * from {{ ref('stg_order_items') }}

),

rollup as (

    select
        order_id,
        sum(quantity) as item_quantity,
        sum(quantity * unit_price_copper) as gross_revenue_copper,
        sum(quantity * unit_price_copper) / 100.0 as gross_revenue_gold,
        count(*) as line_count,
        count(distinct potion_sku) as distinct_potions

    from order_items

>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
    group by order_id

)

<<<<<<< HEAD
select *
from rolled_up
=======
select * from rollup
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
