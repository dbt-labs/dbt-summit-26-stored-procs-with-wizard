{{ config(materialized='view') }}

with source as (

    select *
    from {{ source('merlinco_apothecaries', 'RAW_SHOPS') }}

),

cleaned as (

    select
        shop_id,
        shop_name,
        city,
        initcap(trim(region)) as shop_region,
        try_to_date(opened_at) as opened_at
    from source

)

select *
from cleaned
