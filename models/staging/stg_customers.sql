with source as (

    select
        CUSTOMER_ID,
        FULL_NAME,
        EMAIL,
        HOME_REGION,
        SIGNED_UP_AT,
        BIRTH_YEAR,
        FAVORED_DISCIPLINE
    from {{ source('merlinco_apothecaries', 'RAW_CUSTOMERS') }}

),

renamed as (

    select
        CUSTOMER_ID as customer_id,
        FULL_NAME as full_name,
        lower(trim(EMAIL)) as email,
        case
            when upper(trim(HOME_REGION)) = 'NR' then 'Northern Reaches'
            else initcap(trim(HOME_REGION))
        end as home_region,
        try_to_date(SIGNED_UP_AT) as signed_up_at,
        try_to_number(BIRTH_YEAR) as birth_year,
        initcap(trim(FAVORED_DISCIPLINE)) as favored_discipline
    from source

)

select
    customer_id,
    full_name,
    email,
    home_region,
    signed_up_at,
    birth_year,
    favored_discipline
from renamed
