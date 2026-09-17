with source as (

    select * from {{ source('merlinco_apothecaries', 'RAW_ORDER_ITEMS') }}

),

renamed as (

    select
        order_item_id,
        order_id,
        potion_sku,
        try_to_number(quantity) as quantity,
        try_to_number(unit_price_copper) as unit_price_copper,
        try_to_number(unit_price_copper) / 100.0 as unit_price_gold
    from source

)

select * from renamed
