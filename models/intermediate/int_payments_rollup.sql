with payments as (

    select * from {{ ref('stg_merlinco__payments') }}

),

payments_rollup as (

    select
        order_id,
        sum(
            case
                when payment_status = 'success' then payment_amount
                else 0
            end
        ) as paid_amount,
        max(paid_at) as latest_paid_at,
        max(case when payment_status = 'success' then 1 else 0 end) as has_successful_payment,
        count(*) as payment_attempt_count
    from payments
    group by order_id

)

select * from payments_rollup
