{{ config(materialized='view') }}

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
        ) as membership_rank
    from memberships

),

current_memberships as (

    select
        customer_id,
        guild_id,
        guild_tier,
        valid_from,
        valid_to
    from ranked
    where membership_rank = 1

)

select *
from current_memberships
