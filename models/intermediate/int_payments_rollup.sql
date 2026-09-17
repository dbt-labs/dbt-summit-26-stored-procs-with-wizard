with payments as (

    select
        order_id,
        amount_cents,
        payment_status,
        paid_at
    from {{ ref('stg_payments') }}

),

aggregated as (

    select
        order_id,
        sum(
            case
                when payment_status = 'success' then coalesce(amount_cents, 0)
                else 0
            end
        ) as paid_amount_cents,
        max(paid_at) as latest_paid_at,
        max(
            case when payment_status = 'success' then 1 else 0 end
        ) as has_successful_payment,
        count(*) as payment_attempt_count
    from payments
    group by order_id

),

final as (

    select
        order_id,
        paid_amount_cents,
        paid_amount_cents / 100.0 as paid_amount_dollars,
        latest_paid_at,
        has_successful_payment,
        payment_attempt_count
    from aggregated

)

select * from final
