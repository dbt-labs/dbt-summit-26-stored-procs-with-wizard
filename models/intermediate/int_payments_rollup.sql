with payments as (

<<<<<<< HEAD
    select *
    from {{ ref('stg_payments') }}

),

rolled_up as (

    select
        order_id,
        sum(
            case
                when payment_status = 'success' then coalesce(amount_copper, 0)
                else 0
            end
        ) as paid_amount_copper,
        sum(
            case
                when payment_status = 'success' then coalesce(amount_copper, 0) / 100.0
                else 0
            end
        ) as paid_amount_gold,
        max(paid_at) as latest_paid_at,
        max(case when payment_status = 'success' then 1 else 0 end) as has_successful_payment,
        count(*) as payment_attempt_count
    from payments
=======
    select * from {{ ref('stg_payments') }}

),

rollup as (

    select
        order_id,
        sum(case when status = 'success' then amount_copper else 0 end) as paid_amount_copper,
        sum(case when status = 'success' then amount_copper else 0 end) / 100.0 as paid_amount_gold,
        max(paid_at) as latest_paid_at,
        max(case when status = 'success' then 1 else 0 end) as has_successful_payment,
        count(*) as payment_attempt_count

    from payments

>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
    group by order_id

)

<<<<<<< HEAD
select *
from rolled_up
=======
select * from rollup
>>>>>>> 4169a087ef633cdfd35394649f8d86c8360bf4f7
