with

source as (
    select * from {{ source('merlinco_apothecaries', 'RAW_PAYMENTS') }}
),

cleaned as (
    select
        payment_id,
        order_id,
        method,
        lower(trim(status)) as payment_status,
        coalesce(try_to_number(amount_copper), 0) as amount_copper,
        try_to_timestamp_ntz(paid_at) as paid_at
    from source
)

select * from cleaned
