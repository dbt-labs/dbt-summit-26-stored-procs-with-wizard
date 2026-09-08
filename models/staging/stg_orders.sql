with source as (

    select
        ORDER_ID,
        CUSTOMER_ID,
        SHOP_ID,
        ORDERED_AT,
        STATUS,
        CHANNEL,
        DISCOUNT_COPPER
    from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }}

),

renamed as (

    select
        ORDER_ID as order_id,
        CUSTOMER_ID as customer_id,
        SHOP_ID as shop_id,
        try_to_timestamp_ntz(ORDERED_AT) as ordered_at,
        lower(trim(STATUS)) as order_status,
        lower(trim(CHANNEL)) as order_channel,
        coalesce(try_to_number(DISCOUNT_COPPER), 0) as discount_copper,
        coalesce(try_to_number(DISCOUNT_COPPER), 0) / 100.0 as discount_gold
    from source
    where ORDER_ID is not null

)

select
    order_id,
    customer_id,
    shop_id,
    ordered_at,
    order_status,
    order_channel,
    discount_copper,
    discount_gold
from renamed
