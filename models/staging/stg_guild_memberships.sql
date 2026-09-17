with source as (

    select * from {{ source('merlinco_apothecaries', 'RAW_GUILD_MEMBERSHIPS') }}

),

cleaned as (

    select
        trim(membership_id) as membership_id,
        trim(customer_id) as customer_id,
        trim(guild_id) as guild_id,
        lower(trim(tier)) as guild_tier,
        try_to_date(valid_from) as valid_from,
        try_to_date(nullif(trim(valid_to), '')) as valid_to
    from source

)

select * from cleaned
