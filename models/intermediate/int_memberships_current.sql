with memberships as (

    select * from {{ ref('stg_guild_memberships') }}

),

current_membership as (

    select
        customer_id,
        guild_id,
        guild_tier,
        valid_from,
        valid_to
    from memberships
    qualify row_number() over (
        partition by customer_id
        order by
            coalesce(valid_to, '2999-12-31'::date) desc,
            valid_from desc,
            membership_id desc
    ) = 1

)

select * from current_membership
