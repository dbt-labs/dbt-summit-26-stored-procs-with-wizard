with source as (

    select
        MEMBERSHIP_ID,
        CUSTOMER_ID,
        GUILD_ID,
        TIER,
        VALID_FROM,
        VALID_TO
    from {{ source('merlinco_apothecaries', 'RAW_GUILD_MEMBERSHIPS') }}

),

renamed as (

    select
        MEMBERSHIP_ID as membership_id,
        CUSTOMER_ID as customer_id,
        GUILD_ID as guild_id,
        lower(trim(TIER)) as guild_tier,
        try_to_date(VALID_FROM) as valid_from,
        try_to_date(nullif(VALID_TO, '')) as valid_to
    from source

)

select
    membership_id,
    customer_id,
    guild_id,
    guild_tier,
    valid_from,
    valid_to
from renamed
