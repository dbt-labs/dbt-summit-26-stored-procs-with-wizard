with source as (

    select
        SHOP_ID,
        SHOP_NAME,
        CITY,
        REGION,
        OPENED_AT
    from {{ source('merlinco_apothecaries', 'RAW_SHOPS') }}

),

renamed as (

    select
        SHOP_ID as shop_id,
        SHOP_NAME as shop_name,
        CITY as city,
        initcap(trim(REGION)) as shop_region,
        try_to_date(OPENED_AT) as opened_at
    from source

)

select
    shop_id,
    shop_name,
    city,
    shop_region,
    opened_at
from renamed
