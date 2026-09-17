with source as (

<<<<<<< HEAD
    select *
    from {{ source('merlinco_apothecaries', 'RAW_CUSTOMERS') }}

)

select
    customer_id,
    trim(full_name) as customer_name,
    lower(trim(email)) as email,
    case
        when upper(trim(home_region)) = 'NR' then 'Northern Reaches'
        else initcap(trim(home_region))
    end as home_region,
    try_to_date(signed_up_at) as signed_up_at,
    try_to_number(birth_year) as birth_year,
    initcap(trim(favored_discipline)) as favored_discipline
from source
=======
    select * from {{ source('merlinco_apothecaries', 'RAW_CUSTOMERS') }}

),

renamed as (

    select
        customer_id,
        full_name,
        lower(trim(email)) as email,
        case
            when upper(trim(home_region)) = 'NR' then 'Northern Reaches'
            else initcap(trim(home_region))
        end as home_region,
        try_to_date(signed_up_at) as signed_up_at,
        try_to_number(birth_year) as birth_year,
        initcap(trim(favored_discipline)) as favored_discipline

    from source

)

select * from renamed
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
