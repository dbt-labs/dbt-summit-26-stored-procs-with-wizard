with order_items as (

    select * from {{ ref('stg_merlinco__order_items') }}

),

order_item_rollup as (

    select
        order_id,
        sum(quantity) as item_quantity,
        sum(quantity * unit_price) as gross_revenue,
        count(*) as line_count,
        count(distinct potion_sku) as distinct_potions
    from order_items
    group by order_id

)

select * from order_item_rollup
