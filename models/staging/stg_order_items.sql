with source as (

<<<<<<< HEAD
    select *
    from {{ source('merlinco_apothecaries', 'RAW_ORDER_ITEMS') }}

),

cleaned as (
=======
    select * from {{ source('merlinco_apothecaries', 'RAW_ORDER_ITEMS') }}

),

renamed as (
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7

    select
        order_item_id,
        order_id,
        potion_sku,
        coalesce(try_to_number(quantity), 0) as quantity,
<<<<<<< HEAD
        coalesce(try_to_number(unit_price_copper), 0) as unit_price_cents
=======
        coalesce(try_to_number(unit_price_copper), 0) as unit_price_copper

>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
    from source

)

<<<<<<< HEAD
select
    order_item_id,
    order_id,
    potion_sku,
    quantity,
    unit_price_cents,
    unit_price_cents / 100.0 as unit_price
from cleaned
=======
select * from renamed
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
