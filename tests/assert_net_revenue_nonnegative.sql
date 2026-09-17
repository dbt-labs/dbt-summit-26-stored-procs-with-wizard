-- Net revenue (gross revenue minus discount) must never be negative.
--
-- Confirmed against the full population: minimum net revenue is 0 and zero
-- orders are over-discounted. Refunds and credits are not modeled as negative
-- revenue in this domain, so a negative value here would indicate a discount
-- exceeding gross revenue or a broken upstream copper/gold calculation.
--
-- Fails if any order has negative net revenue in either currency.
select
    order_id,
    gross_revenue_copper,
    discount_copper,
    net_revenue_copper,
    net_revenue_gold
from {{ ref('fct_order_profitability') }}
where net_revenue_copper < 0
   or net_revenue_gold < 0
