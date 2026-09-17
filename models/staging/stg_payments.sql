with source as (

    select
        PAYMENT_ID,
        ORDER_ID,
        METHOD,
        AMOUNT_COPPER,
        STATUS,
        PAID_AT
    from {{ source('merlinco_apothecaries', 'RAW_PAYMENTS') }}

),

cleaned as (

    select
        PAYMENT_ID as payment_id,
        ORDER_ID as order_id,
        METHOD as payment_method,
        coalesce(try_to_number(AMOUNT_COPPER), 0) as amount_copper,
        lower(trim(STATUS)) as payment_status,
        try_to_timestamp_ntz(PAID_AT) as paid_at
    from source

)

select
    payment_id,
    order_id,
    payment_method,
    amount_copper,
    payment_status,
    paid_at
from cleaned
