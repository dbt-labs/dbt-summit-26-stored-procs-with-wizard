with source as (

    select
        membership_id,
        customer_id,
        guild_id,
        tier,
        valid_from,
        valid_to
    from {{ source('merlinco_apothecaries', 'RAW_GUILD_MEMBERSHIPS') }}

),

cleaned as (

    select
        membership_id,
        customer_id,
        guild_id,
        lower(trim(tier)) as guild_tier,
        try_to_date(valid_from) as valid_from,
        try_to_date(nullif(valid_to, '')) as valid_to
    from source

)

select * from cleaned
