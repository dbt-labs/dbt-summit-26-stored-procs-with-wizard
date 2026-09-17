with source as (

    select *
    from {{ source('merlinco_apothecaries', 'RAW_PAYMENTS') }}

),

renamed as (

    select
        payment_id,
        order_id,
        method,
        try_to_number(amount_copper) as amount_copper,
        lower(trim(status)) as payment_status,
        try_to_timestamp_ntz(paid_at) as paid_at
    from source

)

select *
from renamed
