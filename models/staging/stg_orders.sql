{{ config(materialized='view') }}

with source as (

    select *
    from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }}

),

cleaned as (

    select
        order_id,
        customer_id,
        shop_id,
        try_to_timestamp_ntz(ordered_at) as ordered_at,
        lower(trim(status)) as order_status,
        lower(trim(channel)) as order_channel,
        coalesce(try_to_number(discount_copper), 0) as discount_copper,
        coalesce(try_to_number(discount_copper), 0) / 100.0 as discount_gold
    from source
    where order_id is not null

)

select *
from cleaned
