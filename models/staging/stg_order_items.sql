with source as (

    select * from {{ source('merlinco_apothecaries', 'RAW_ORDER_ITEMS') }}

),

cleaned as (

    select
        trim(order_item_id) as order_item_id,
        trim(order_id) as order_id,
        trim(potion_sku) as potion_sku,
        try_to_number(quantity) as quantity,
        try_to_number(unit_price_copper) as unit_price_cents,
        try_to_number(unit_price_copper) / 100.0 as unit_price_dollars
    from source

)

select * from cleaned
