-- Every order is expected to have at least one line item. A null `item_quantity` in
-- fct_order_profitability means int_order_item_rollup has no row for that order_id,
-- which points to an ingestion defect (an order placed with no recorded items) rather
-- than a valid business state. This test fails if any such order appears.

select
    order_id,
    item_quantity,
    line_count,
    distinct_potions
from {{ ref('fct_order_profitability') }}
where item_quantity is null
