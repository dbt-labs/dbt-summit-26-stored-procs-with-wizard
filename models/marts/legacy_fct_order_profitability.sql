{{
    config(
        enabled=var('enable_order_revenue_compatibility_view', false),
        materialized='view',
        alias='legacy_fct_order_profitability'
    )
}}

select *
from {{ ref('fct_order_revenue') }}
