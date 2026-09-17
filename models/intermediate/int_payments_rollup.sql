with payments as (

    select *
    from {{ ref('stg_payments') }}

)

select
    order_id,
    sum(
        case
            when payment_status = 'success' then amount
            else 0
        end
    ) as paid_amount,
    max(
        case
            when payment_status = 'success' then 1
            else 0
        end
    ) as has_successful_payment
from payments
group by order_id
