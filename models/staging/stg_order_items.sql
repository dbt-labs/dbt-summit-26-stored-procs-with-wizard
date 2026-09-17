with source as (

    select *
    from {{ source('merlinco_apothecaries', 'RAW_ORDER_ITEMS') }}

),

cleaned as (

    select
        order_item_id,
        order_id,
        potion_sku,
        coalesce(try_to_number(quantity), 0) as quantity,
        coalesce(try_to_number(unit_price_copper), 0) as unit_price_cents
    from source

)

select
    order_item_id,
    order_id,
    potion_sku,
    quantity,
    unit_price_cents,
    unit_price_cents / 100.0 as unit_price
from cleaned
