with order_items as (

    select * from {{ ref('stg_order_items') }}

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
    group by order_id

)

select * from rolled_up
