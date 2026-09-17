with source as (

    select
        ORDER_ITEM_ID,
        ORDER_ID,
        POTION_SKU,
        QUANTITY,
        UNIT_PRICE_COPPER
    from {{ source('merlinco_apothecaries', 'RAW_ORDER_ITEMS') }}

),

cleaned as (

    select
        ORDER_ITEM_ID as order_item_id,
        ORDER_ID as order_id,
        POTION_SKU as potion_sku,
        coalesce(try_to_number(QUANTITY), 0) as quantity,
        coalesce(try_to_number(UNIT_PRICE_COPPER), 0) as unit_price_copper
    from source

)

select
    order_item_id,
    order_id,
    potion_sku,
    quantity,
    unit_price_copper
from cleaned
