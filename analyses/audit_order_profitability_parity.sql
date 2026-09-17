{% set legacy_query %}

with orders_clean as (

    select
        order_id,
        customer_id,
        shop_id,
        try_to_timestamp_ntz(ordered_at) as ordered_at,
        lower(trim(status)) as order_status,
        lower(trim(channel)) as order_channel,
        coalesce(try_to_number(discount_copper), 0) as discount_copper,
        coalesce(try_to_number(discount_copper), 0) / 100.0 as discount_gold
    from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }}
    where order_id is not null

),

order_item_rollup as (

    select
        order_id,
        sum(coalesce(try_to_number(quantity), 0)) as item_quantity,
        sum(
            coalesce(try_to_number(quantity), 0)
            * coalesce(try_to_number(unit_price_copper), 0)
        ) as gross_revenue_copper,
        sum(
            (
                coalesce(try_to_number(quantity), 0)
                * coalesce(try_to_number(unit_price_copper), 0)
            ) / 100.0
        ) as gross_revenue_gold,
        count(*) as line_count,
        count(distinct potion_sku) as distinct_potions
    from {{ source('merlinco_apothecaries', 'RAW_ORDER_ITEMS') }}
    group by order_id

),

payments_rollup as (

    select
        order_id,
        sum(
            case
                when lower(trim(status)) = 'success'
                    then coalesce(try_to_number(amount_copper), 0)
                else 0
            end
        ) as paid_amount_copper,
        sum(
            case
                when lower(trim(status)) = 'success'
                    then coalesce(try_to_number(amount_copper), 0) / 100.0
                else 0
            end
        ) as paid_amount_gold,
        max(try_to_timestamp_ntz(paid_at)) as latest_paid_at,
        max(case when lower(trim(status)) = 'success' then 1 else 0 end) as has_successful_payment,
        count(*) as payment_attempt_count
    from {{ source('merlinco_apothecaries', 'RAW_PAYMENTS') }}
    group by order_id

),

membership_ranked as (

    select
        membership_id,
        customer_id,
        guild_id,
        lower(trim(tier)) as guild_tier,
        try_to_date(valid_from) as valid_from,
        try_to_date(nullif(valid_to, '')) as valid_to,
        row_number() over (
            partition by customer_id
            order by
                coalesce(try_to_date(nullif(valid_to, '')), '2999-12-31'::date) desc,
                try_to_date(valid_from) desc,
                membership_id desc
        ) as membership_rank
    from {{ source('merlinco_apothecaries', 'RAW_GUILD_MEMBERSHIPS') }}

),

membership_current as (

    select
        customer_id,
        guild_id,
        guild_tier,
        valid_from,
        valid_to
    from membership_ranked
    where membership_rank = 1

),

customer_clean as (

    select
        customer_id,
        full_name,
        lower(trim(email)) as email,
        case
            when upper(trim(home_region)) = 'NR' then 'Northern Reaches'
            else initcap(trim(home_region))
        end as home_region,
        try_to_date(signed_up_at) as signed_up_at,
        try_to_number(birth_year) as birth_year,
        initcap(trim(favored_discipline)) as favored_discipline
    from {{ source('merlinco_apothecaries', 'RAW_CUSTOMERS') }}

),

shop_clean as (

    select
        shop_id,
        shop_name,
        city,
        initcap(trim(region)) as shop_region,
        try_to_date(opened_at) as opened_at
    from {{ source('merlinco_apothecaries', 'RAW_SHOPS') }}

)

select
    orders_clean.order_id,
    orders_clean.customer_id,
    customer_clean.full_name as customer_name,
    customer_clean.email as customer_email,
    customer_clean.home_region,
    customer_clean.favored_discipline,
    membership_current.guild_id,
    membership_current.guild_tier,
    orders_clean.shop_id,
    shop_clean.shop_name,
    shop_clean.city as shop_city,
    shop_clean.shop_region,
    orders_clean.ordered_at,
    cast(orders_clean.ordered_at as date) as ordered_date,
    orders_clean.order_status,
    orders_clean.order_channel,
    order_item_rollup.item_quantity,
    order_item_rollup.line_count,
    order_item_rollup.distinct_potions,
    order_item_rollup.gross_revenue_copper,
    order_item_rollup.gross_revenue_gold,
    orders_clean.discount_copper,
    orders_clean.discount_gold,
    order_item_rollup.gross_revenue_copper - orders_clean.discount_copper as net_revenue_copper,
    order_item_rollup.gross_revenue_gold - orders_clean.discount_gold as net_revenue_gold,
    payments_rollup.paid_amount_copper,
    payments_rollup.paid_amount_gold,
    payments_rollup.latest_paid_at,
    payments_rollup.payment_attempt_count,
    case
        when coalesce(payments_rollup.has_successful_payment, 0) = 1 then 'paid'
        when orders_clean.order_status in ('cancelled', 'canceled') then 'cancelled'
        else 'unpaid'
    end as payment_state,
    case
        when customer_clean.home_region = shop_clean.shop_region then true
        else false
    end as is_home_region_order
from orders_clean
left join order_item_rollup
    on orders_clean.order_id = order_item_rollup.order_id
left join payments_rollup
    on orders_clean.order_id = payments_rollup.order_id
left join customer_clean
    on orders_clean.customer_id = customer_clean.customer_id
left join membership_current
    on orders_clean.customer_id = membership_current.customer_id
left join shop_clean
    on orders_clean.shop_id = shop_clean.shop_id

{% endset %}

{% set dbt_query %}

select *
from {{ ref('fct_order_profitability') }}

{% endset %}

{% set audit_query %}

{{
    audit_helper.compare_and_classify_query_results(
        a_query=legacy_query,
        b_query=dbt_query,
        primary_key_columns=['order_id'],
        columns=[
            'order_id',
            'customer_id',
            'customer_name',
            'customer_email',
            'home_region',
            'favored_discipline',
            'guild_id',
            'guild_tier',
            'shop_id',
            'shop_name',
            'shop_city',
            'shop_region',
            'ordered_at',
            'ordered_date',
            'order_status',
            'order_channel',
            'item_quantity',
            'line_count',
            'distinct_potions',
            'gross_revenue_copper',
            'gross_revenue_gold',
            'discount_copper',
            'discount_gold',
            'net_revenue_copper',
            'net_revenue_gold',
            'paid_amount_copper',
            'paid_amount_gold',
            'latest_paid_at',
            'payment_attempt_count',
            'payment_state',
            'is_home_region_order'
        ],
        sample_limit=none
    )
}}

{% endset %}

with audit_results as (

    {{ audit_query }}

)

select
    dbt_audit_row_status,
    max(dbt_audit_num_rows_in_status) as compared_key_count
from audit_results
group by dbt_audit_row_status
order by dbt_audit_row_status
