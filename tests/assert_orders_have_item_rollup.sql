-- Every order is expected to have at least one line item, so item measures
-- should never be null in the fact.
--
-- Confirmed against the full population: all 75,000 orders have an item rollup.
-- A null item_quantity therefore signals a missing/dropped raw_order_items
-- ingestion (a defect), not a valid business state.
--
-- Note the deliberate asymmetry with payments: ~1,315 orders legitimately have
-- no payment attempts (unpaid/cancelled), so payment measures are allowed to be
-- null and are intentionally NOT guarded this way.
--
-- Fails if any order is missing its item rollup.
select
    order_id,
    item_quantity,
    line_count,
    gross_revenue_copper
from {{ ref('fct_order_profitability') }}
where item_quantity is null
