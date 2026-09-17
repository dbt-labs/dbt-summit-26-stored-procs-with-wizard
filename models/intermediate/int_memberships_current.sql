with memberships as (

<<<<<<< HEAD
    select *
    from {{ ref('stg_guild_memberships') }}
=======
    select * from {{ ref('stg_guild_memberships') }}
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7

),

ranked as (

    select
<<<<<<< HEAD
        membership_id,
=======
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
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
<<<<<<< HEAD
        ) as membership_rank
=======
        ) as rn

>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
    from memberships

),

<<<<<<< HEAD
current_memberships as (
=======
current_membership as (
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7

    select
        customer_id,
        guild_id,
        guild_tier,
        valid_from,
        valid_to
<<<<<<< HEAD
    from ranked
    where membership_rank = 1

)

select *
from current_memberships
=======

    from ranked

    where rn = 1

)

select * from current_membership
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
