with payments as (

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

    group by order_id

)

select * from rollup
