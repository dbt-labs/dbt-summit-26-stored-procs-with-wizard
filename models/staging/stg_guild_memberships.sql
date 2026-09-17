with source as (

<<<<<<< HEAD
    select *
    from {{ source('merlinco_apothecaries', 'RAW_GUILD_MEMBERSHIPS') }}

),

cleaned as (
=======
    select * from {{ source('merlinco_apothecaries', 'RAW_GUILD_MEMBERSHIPS') }}

),

renamed as (
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7

    select
        membership_id,
        customer_id,
        guild_id,
        lower(trim(tier)) as guild_tier,
        try_to_date(valid_from) as valid_from,
        try_to_date(nullif(valid_to, '')) as valid_to
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
