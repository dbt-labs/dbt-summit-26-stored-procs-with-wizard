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
    from RAW.MERLINCO_APOTHECARIES.RAW_ORDERS
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
    from RAW.MERLINCO_APOTHECARIES.RAW_ORDER_ITEMS
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
    from RAW.MERLINCO_APOTHECARIES.RAW_PAYMENTS
    group by order_id

),

memberships_current as (

    select
        customer_id,
        guild_id,
        lower(trim(tier)) as guild_tier
    from RAW.MERLINCO_APOTHECARIES.RAW_GUILD_MEMBERSHIPS
    qualify row_number() over (
        partition by customer_id
        order by
            coalesce(try_to_date(nullif(valid_to, '')), '2999-12-31'::date) desc,
            try_to_date(valid_from) desc,
            membership_id desc
    ) = 1

),

customers_clean as (

    select
        customer_id,
        full_name,
        lower(trim(email)) as email,
        case
            when upper(trim(home_region)) = 'NR' then 'Northern Reaches'
            else initcap(trim(home_region))
        end as home_region,
        initcap(trim(favored_discipline)) as favored_discipline
    from RAW.MERLINCO_APOTHECARIES.RAW_CUSTOMERS

),

shops_clean as (

    select
        shop_id,
        shop_name,
        city,
        initcap(trim(region)) as shop_region
    from RAW.MERLINCO_APOTHECARIES.RAW_SHOPS

)

select
    orders.order_id,
    orders.customer_id,
    customers.full_name as customer_name,
    customers.email as customer_email,
    customers.home_region,
    customers.favored_discipline,
    memberships.guild_id,
    memberships.guild_tier,
    orders.shop_id,
    shops.shop_name,
    shops.city as shop_city,
    shops.shop_region,
    orders.ordered_at,
    cast(orders.ordered_at as date) as ordered_date,
    orders.order_status,
    orders.order_channel,
    order_items.item_quantity,
    order_items.line_count,
    order_items.distinct_potions,
    order_items.gross_revenue_copper,
    order_items.gross_revenue_gold,
    orders.discount_copper,
    orders.discount_gold,
    order_items.gross_revenue_copper - orders.discount_copper as net_revenue_copper,
    order_items.gross_revenue_gold - orders.discount_gold as net_revenue_gold,
    payments.paid_amount_copper,
    payments.paid_amount_gold,
    payments.latest_paid_at,
    payments.payment_attempt_count,
    case
        when coalesce(payments.has_successful_payment, 0) = 1 then 'paid'
        when orders.order_status in ('cancelled', 'canceled') then 'cancelled'
        else 'unpaid'
    end as payment_state,
    case
        when customers.home_region = shops.shop_region then true
        else false
    end as is_home_region_order
from orders_clean as orders
left join order_item_rollup as order_items
    on orders.order_id = order_items.order_id
left join payments_rollup as payments
    on orders.order_id = payments.order_id
left join customers_clean as customers
    on orders.customer_id = customers.customer_id
left join memberships_current as memberships
    on orders.customer_id = memberships.customer_id
left join shops_clean as shops
    on orders.shop_id = shops.shop_id
{% endset %}

{% set dbt_query %}
select
    order_id,
    customer_id,
    customer_name,
    customer_email,
    home_region,
    favored_discipline,
    guild_id,
    guild_tier,
    shop_id,
    shop_name,
    shop_city,
    shop_region,
    ordered_at,
    ordered_date,
    order_status,
    order_channel,
    item_quantity,
    line_count,
    distinct_potions,
    gross_revenue_copper,
    gross_revenue_gold,
    discount_copper,
    discount_gold,
    net_revenue_copper,
    net_revenue_gold,
    paid_amount_copper,
    paid_amount_gold,
    latest_paid_at,
    payment_attempt_count,
    payment_state,
    is_home_region_order
from {{ ref('fct_order_profitability') }}
{% endset %}

{% set business_columns = [
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

with audit_results as (

    {{
        audit_helper.compare_and_classify_query_results(
            a_query=legacy_query,
            b_query=dbt_query,
            primary_key_columns=['order_id'],
            columns=business_columns,
            sample_limit=10
        )
    }}

)

select
    dbt_audit_row_status,
    max(dbt_audit_num_rows_in_status) as order_count
from audit_results
group by dbt_audit_row_status
order by dbt_audit_row_status
