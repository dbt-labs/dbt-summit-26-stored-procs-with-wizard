with source as (

    select *
    from {{ source('merlinco_apothecaries', 'RAW_PAYMENTS') }}

),

cleaned as (

    select
        payment_id,
        order_id,
        method as payment_method,
        lower(trim(status)) as payment_status,
        coalesce(try_to_number(amount_copper), 0) as amount_cents,
        try_to_timestamp_ntz(paid_at) as paid_at
    from source

)

select
    payment_id,
    order_id,
    payment_method,
    payment_status,
    amount_cents,
    amount_cents / 100.0 as amount,
    paid_at
from cleaned
