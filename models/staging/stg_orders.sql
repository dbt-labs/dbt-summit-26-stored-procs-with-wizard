with source as (

<<<<<<< HEAD
    select *
    from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }}

),

cleaned as (
=======
    select * from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }}

),

renamed as (
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7

    select
        order_id,
        customer_id,
        shop_id,
        try_to_timestamp_ntz(ordered_at) as ordered_at,
        lower(trim(status)) as order_status,
        lower(trim(channel)) as order_channel,
        coalesce(try_to_number(discount_copper), 0) as discount_copper,
        coalesce(try_to_number(discount_copper), 0) / 100.0 as discount_gold
<<<<<<< HEAD
    from source
=======

    from source

>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
    where order_id is not null

)

<<<<<<< HEAD
select *
from cleaned
=======
select * from renamed
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
