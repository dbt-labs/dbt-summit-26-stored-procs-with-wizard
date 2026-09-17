with source as (

    select * from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }}

),

cleaned as (

    select
        trim(order_id) as order_id,
        trim(customer_id) as customer_id,
        trim(shop_id) as shop_id,
        try_to_timestamp_ntz(ordered_at) as ordered_at,
        lower(trim(status)) as order_status,
        lower(trim(channel)) as order_channel,
        try_to_number(discount_copper) as discount_cents,
        try_to_number(discount_copper) / 100.0 as discount_dollars
    from source

)

select * from cleaned
