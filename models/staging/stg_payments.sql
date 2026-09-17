with source as (

<<<<<<< HEAD
    select *
    from {{ source('merlinco_apothecaries', 'RAW_PAYMENTS') }}

),

cleaned as (
=======
    select * from {{ source('merlinco_apothecaries', 'RAW_PAYMENTS') }}

),

renamed as (
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7

    select
        payment_id,
        order_id,
<<<<<<< HEAD
        method as payment_method,
        lower(trim(status)) as payment_status,
        coalesce(try_to_number(amount_copper), 0) as amount_cents,
        try_to_timestamp_ntz(paid_at) as paid_at
=======
        method,
        coalesce(try_to_number(amount_copper), 0) as amount_copper,
        lower(trim(status)) as status,
        try_to_timestamp_ntz(paid_at) as paid_at

>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
    from source

)

<<<<<<< HEAD
select
    payment_id,
    order_id,
    payment_method,
    payment_status,
    amount_cents,
    amount_cents / 100.0 as amount,
    paid_at
from cleaned
=======
select * from renamed
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
