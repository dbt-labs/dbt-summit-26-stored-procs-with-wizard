{{ config(materialized='view') }}

with payments as (

    select *
    from {{ ref('stg_payments') }}

),

rolled_up as (

    select
        order_id,
        sum(case when payment_status = 'success' then amount_copper else 0 end) as paid_amount_copper,
        sum(case when payment_status = 'success' then amount_copper / 100.0 else 0 end) as paid_amount_gold,
        max(paid_at) as latest_paid_at,
        max(case when payment_status = 'success' then 1 else 0 end) as has_successful_payment,
        count(*) as payment_attempt_count
    from payments
    group by order_id

)

select *
from rolled_up
