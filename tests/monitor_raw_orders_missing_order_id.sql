{{ config(severity='warn') }}

select
    order_id
from {{ source('merlinco_apothecaries', 'RAW_ORDERS') }}
where order_id is null
