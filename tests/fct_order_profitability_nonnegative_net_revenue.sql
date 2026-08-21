-- Discounts must not exceed item revenue. This guards the net-revenue contract confirmed in the parity-ready production fact.

select *
from {{ ref('fct_order_profitability') }}
where net_revenue_gold < 0
