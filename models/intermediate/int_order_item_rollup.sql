with order_items as (

    select
        order_id,
        potion_sku,
        quantity,
        unit_price_cents
    from {{ ref('stg_order_items') }}

),

aggregated as (

    select
        order_id,
        sum(coalesce(quantity, 0)) as item_quantity,
        sum(
            coalesce(quantity, 0) * coalesce(unit_price_cents, 0)
        ) as gross_revenue_cents,
        count(*) as line_count,
        count(distinct potion_sku) as distinct_potions
    from order_items
    group by order_id

),

final as (

    select
        order_id,
        item_quantity,
        gross_revenue_cents,
        gross_revenue_cents / 100.0 as gross_revenue_dollars,
        line_count,
        distinct_potions
    from aggregated

)

select * from final
