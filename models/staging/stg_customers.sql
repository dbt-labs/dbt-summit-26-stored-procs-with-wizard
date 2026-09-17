with source as (

    select
        customer_id,
        full_name,
        email,
        home_region,
        signed_up_at,
        birth_year,
        favored_discipline
    from {{ source('merlinco_apothecaries', 'RAW_CUSTOMERS') }}

),

cleaned as (

    select
        customer_id,
        full_name,
        lower(trim(email)) as email,
        case upper(trim(home_region))
            when 'NR' then 'Northern Reaches'
            when 'CV' then 'Crystal Vale'
            when 'EC' then 'Ember Coast'
            when 'SW' then 'Silverwood'
            when 'ML' then 'The Marshlands'
            else initcap(trim(home_region))
        end as home_region,
        try_to_date(signed_up_at) as signed_up_at,
        try_to_number(birth_year) as birth_year,
        initcap(trim(favored_discipline)) as favored_discipline
    from source

)

select * from cleaned
