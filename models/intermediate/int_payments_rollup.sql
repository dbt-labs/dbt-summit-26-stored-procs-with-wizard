with payments as (

    select
        order_id,
        amount_copper,
        payment_status,
        paid_at
    from {{ ref('stg_payments') }}

),

aggregated as (

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
    group by order_id

)

select
    order_id,
    paid_amount_copper,
    paid_amount_gold,
    latest_paid_at,
    has_successful_payment,
    payment_attempt_count
from aggregated
