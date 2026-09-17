with source as (

    select *
    from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }}

),

cleaned as (

    select
        order_id,
        customer_id,
        try_to_timestamp_ntz(ordered_at) as ordered_at,
        lower(trim(status)) as order_status,
        lower(trim(channel)) as order_channel,
        coalesce(try_to_number(discount_copper), 0) as discount_cents
    from source
    where order_id is not null

)

select
    order_id,
    customer_id,
    ordered_at,
    order_status,
    order_channel,
    discount_cents,
    discount_cents / 100.0 as discount
from cleaned
