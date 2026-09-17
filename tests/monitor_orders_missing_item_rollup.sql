{{ config(severity='warn') }}

select
    order_id
from {{ ref('fct_order_revenue') }}
where item_quantity is null
