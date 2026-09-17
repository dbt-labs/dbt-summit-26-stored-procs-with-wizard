with memberships as (

    select *
    from {{ ref('stg_guild_memberships') }}

),

ranked as (

    select
        membership_id,
        customer_id,
        guild_id,
        guild_tier,
        valid_from,
        valid_to,
        row_number() over (
            partition by customer_id
            order by
                coalesce(valid_to, '2999-12-31'::date) desc,
                valid_from desc,
                membership_id desc
        ) as row_number
    from memberships

)

select
    customer_id,
    guild_id,
    guild_tier,
    valid_from,
    valid_to
from ranked
where row_number = 1
