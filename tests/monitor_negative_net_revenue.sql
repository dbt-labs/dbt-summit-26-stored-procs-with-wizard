{{ config(severity='warn') }}

select
    order_id,
    net_revenue_copper,
    net_revenue_gold
from {{ ref('fct_order_revenue') }}
where net_revenue_copper < 0
   or net_revenue_gold < 0
