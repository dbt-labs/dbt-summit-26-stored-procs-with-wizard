with source as (

<<<<<<< HEAD
    select *
    from {{ source('merlinco_apothecaries', 'RAW_SHOPS') }}

),

cleaned as (
=======
    select * from {{ source('merlinco_apothecaries', 'RAW_SHOPS') }}

),

renamed as (
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7

    select
        shop_id,
        shop_name,
        city,
        initcap(trim(region)) as shop_region,
        try_to_date(opened_at) as opened_at
<<<<<<< HEAD
=======

>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
    from source

)

<<<<<<< HEAD
select *
from cleaned
=======
select * from renamed
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
