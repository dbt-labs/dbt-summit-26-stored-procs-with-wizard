with source as (

    select * from {{ source('merlinco_apothecaries', 'RAW_CUSTOMERS') }}

),

cleaned as (

    select
        trim(customer_id) as customer_id,
        trim(full_name) as full_name,
        lower(trim(email)) as email,
        upper(trim(home_region)) as home_region,
        try_to_date(signed_up_at) as signed_up_at,
        try_to_number(birth_year) as birth_year,
        initcap(trim(favored_discipline)) as favored_discipline
    from source

)

select * from cleaned
