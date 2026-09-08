{% set columns_to_compare = [
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
] %}

{% set legacy_query %}
    with orders_clean as (
        select
            o.order_id,
            o.customer_id,
            o.shop_id,
            try_to_timestamp_ntz(o.ordered_at) as ordered_at,
            lower(trim(o.status)) as order_status,
            lower(trim(o.channel)) as order_channel,
            coalesce(try_to_number(o.discount_copper), 0) as discount_copper,
            coalesce(try_to_number(o.discount_copper), 0) / 100.0 as discount_gold
        from RAW.MERLINCO_APOTHECARIES.raw_orders o
        where o.order_id is not null
    ),

    order_item_rollup as (
        select
            oi.order_id,
            sum(coalesce(try_to_number(oi.quantity), 0)) as item_quantity,
            sum(
                coalesce(try_to_number(oi.quantity), 0)
                * coalesce(try_to_number(oi.unit_price_copper), 0)
            ) as gross_revenue_copper,
            sum(
                (
                    coalesce(try_to_number(oi.quantity), 0)
                    * coalesce(try_to_number(oi.unit_price_copper), 0)
                ) / 100.0
            ) as gross_revenue_gold,
            count(*) as line_count,
            count(distinct oi.potion_sku) as distinct_potions
        from RAW.MERLINCO_APOTHECARIES.raw_order_items oi
        group by 1
    ),

    payments_rollup as (
        select
            p.order_id,
            sum(
                case
                    when lower(trim(p.status)) = 'success'
                        then coalesce(try_to_number(p.amount_copper), 0)
                    else 0
                end
            ) as paid_amount_copper,
            sum(
                case
                    when lower(trim(p.status)) = 'success'
                        then coalesce(try_to_number(p.amount_copper), 0) / 100.0
                    else 0
                end
            ) as paid_amount_gold,
            max(try_to_timestamp_ntz(p.paid_at)) as latest_paid_at,
            max(case when lower(trim(p.status)) = 'success' then 1 else 0 end) as has_successful_payment,
            count(*) as payment_attempt_count
        from RAW.MERLINCO_APOTHECARIES.raw_payments p
        group by 1
    ),

    membership_current as (
        select
            customer_id,
            guild_id,
            lower(trim(tier)) as guild_tier
        from (
            select
                gm.*,
                row_number() over (
                    partition by gm.customer_id
                    order by
                        coalesce(try_to_date(nullif(gm.valid_to, '')), '2999-12-31'::date) desc,
                        try_to_date(gm.valid_from) desc,
                        gm.membership_id desc
                ) as rn
            from RAW.MERLINCO_APOTHECARIES.raw_guild_memberships gm
        ) deduped
        where rn = 1
    ),

    customer_clean as (
        select
            c.customer_id,
            c.full_name,
            lower(trim(c.email)) as email,
            case
                when upper(trim(c.home_region)) = 'NR' then 'Northern Reaches'
                else initcap(trim(c.home_region))
            end as home_region,
            initcap(trim(c.favored_discipline)) as favored_discipline
        from RAW.MERLINCO_APOTHECARIES.raw_customers c
    ),

    shop_clean as (
        select
            s.shop_id,
            s.shop_name,
            s.city,
            initcap(trim(s.region)) as shop_region
        from RAW.MERLINCO_APOTHECARIES.raw_shops s
    ),

    order_profitability as (
        select
            o.order_id,
            o.customer_id,
            c.full_name as customer_name,
            c.email as customer_email,
            c.home_region,
            c.favored_discipline,
            m.guild_id,
            m.guild_tier,
            o.shop_id,
            s.shop_name,
            s.city as shop_city,
            s.shop_region,
            o.ordered_at,
            cast(o.ordered_at as date) as ordered_date,
            o.order_status,
            o.order_channel,
            i.item_quantity,
            i.line_count,
            i.distinct_potions,
            i.gross_revenue_copper,
            i.gross_revenue_gold,
            o.discount_copper,
            o.discount_gold,
            i.gross_revenue_copper - o.discount_copper as net_revenue_copper,
            i.gross_revenue_gold - o.discount_gold as net_revenue_gold,
            p.paid_amount_copper,
            p.paid_amount_gold,
            p.latest_paid_at,
            p.payment_attempt_count,
            case
                when coalesce(p.has_successful_payment, 0) = 1 then 'paid'
                when o.order_status in ('cancelled', 'canceled') then 'cancelled'
                else 'unpaid'
            end as payment_state,
            case
                when c.home_region = s.shop_region then true
                else false
            end as is_home_region_order
        from orders_clean o
        left join order_item_rollup i
            on o.order_id = i.order_id
        left join payments_rollup p
            on o.order_id = p.order_id
        left join customer_clean c
            on o.customer_id = c.customer_id
        left join membership_current m
            on o.customer_id = m.customer_id
        left join shop_clean s
            on o.shop_id = s.shop_id
    )

    select
        {{ columns_to_compare | join(',\n        ') }}
    from order_profitability
{% endset %}


{% set dbt_query %}
    select
        {{ columns_to_compare | join(',\n        ') }}
    from {{ ref('fct_order_profitability') }}
{% endset %}

with audit_results as (

    {{ audit_helper.compare_and_classify_query_results(
        a_query=legacy_query,
        b_query=dbt_query,
        primary_key_columns=['order_id'],
        columns=columns_to_compare,
        sample_limit=20
    ) }}

)

select
    dbt_audit_row_status,
    max(dbt_audit_num_rows_in_status) as order_count
from audit_results
group by 1
order by 1

