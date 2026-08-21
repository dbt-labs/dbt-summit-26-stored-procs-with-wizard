-- Every order must have a corresponding item rollup. A missing rollup indicates an order-item ingestion or aggregation defect.

select *
from {{ ref('fct_order_profitability') }}
where item_quantity is null
   or line_count is null
   or distinct_potions is null
