with source as (

    select * from {{ source('merlinco_apothecaries', 'RAW_SHOPS') }}

),

cleaned as (

    select
        trim(shop_id) as shop_id,
        trim(shop_name) as shop_name,
        trim(city) as city,
        upper(trim(region)) as shop_region,
        try_to_date(opened_at) as opened_at
    from source

)

select * from cleaned
