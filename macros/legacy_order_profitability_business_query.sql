{% macro legacy_order_profitability_business_query() %}

with orders_clean as (

    select
        orders.order_id,
        orders.customer_id,
        orders.shop_id,
        try_to_timestamp_ntz(orders.ordered_at) as ordered_at,
        lower(trim(orders.status)) as order_status,
        lower(trim(orders.channel)) as order_channel,
        coalesce(try_to_number(orders.discount_copper), 0) as discount_copper,
        coalesce(try_to_number(orders.discount_copper), 0) / 100.0 as discount_gold
    from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }} as orders
    where orders.order_id is not null

),

order_item_rollup as (

    select
        order_items.order_id,
        sum(coalesce(try_to_number(order_items.quantity), 0)) as item_quantity,
        sum(
            coalesce(try_to_number(order_items.quantity), 0)
            * coalesce(try_to_number(order_items.unit_price_copper), 0)
        ) as gross_revenue_copper,
        sum(
            (
                coalesce(try_to_number(order_items.quantity), 0)
                * coalesce(try_to_number(order_items.unit_price_copper), 0)
            ) / 100.0
        ) as gross_revenue_gold,
        count(*) as line_count,
        count(distinct order_items.potion_sku) as distinct_potions
    from {{ source('merlinco_apothecaries', 'RAW_ORDER_ITEMS') }} as order_items
    group by order_items.order_id

),

payments_rollup as (

    select
        payments.order_id,
        sum(
            case
                when lower(trim(payments.status)) = 'success'
                    then coalesce(try_to_number(payments.amount_copper), 0)
                else 0
            end
        ) as paid_amount_copper,
        sum(
            case
                when lower(trim(payments.status)) = 'success'
                    then coalesce(try_to_number(payments.amount_copper), 0) / 100.0
                else 0
            end
        ) as paid_amount_gold,
        max(try_to_timestamp_ntz(payments.paid_at)) as latest_paid_at,
        max(case when lower(trim(payments.status)) = 'success' then 1 else 0 end) as has_successful_payment,
        count(*) as payment_attempt_count
    from {{ source('merlinco_apothecaries', 'RAW_PAYMENTS') }} as payments
    group by payments.order_id

),

membership_current as (

    select
        customer_id,
        guild_id,
        lower(trim(tier)) as guild_tier,
        try_to_date(valid_from) as valid_from,
        try_to_date(nullif(valid_to, '')) as valid_to
    from {{ source('merlinco_apothecaries', 'RAW_GUILD_MEMBERSHIPS') }} as memberships
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
        customers.customer_id,
        customers.full_name,
        lower(trim(customers.email)) as email,
        case
            when upper(trim(customers.home_region)) = 'NR' then 'Northern Reaches'
            else initcap(trim(customers.home_region))
        end as home_region,
        initcap(trim(customers.favored_discipline)) as favored_discipline
    from {{ source('merlinco_apothecaries', 'RAW_CUSTOMERS') }} as customers

),

shops_clean as (

    select
        shops.shop_id,
        shops.shop_name,
        shops.city,
        initcap(trim(shops.region)) as shop_region
    from {{ source('merlinco_apothecaries', 'RAW_SHOPS') }} as shops

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
    items.item_quantity,
    items.line_count,
    items.distinct_potions,
    items.gross_revenue_copper,
    items.gross_revenue_gold,
    orders.discount_copper,
    orders.discount_gold,
    items.gross_revenue_copper - orders.discount_copper as net_revenue_copper,
    items.gross_revenue_gold - orders.discount_gold as net_revenue_gold,
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
left join order_item_rollup as items
    on orders.order_id = items.order_id
left join payments_rollup as payments
    on orders.order_id = payments.order_id
left join customers_clean as customers
    on orders.customer_id = customers.customer_id
left join membership_current as memberships
    on orders.customer_id = memberships.customer_id
left join shops_clean as shops
    on orders.shop_id = shops.shop_id

{% endmacro %}
