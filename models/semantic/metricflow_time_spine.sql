{{ config(materialized='table') }}

with days as (

    {{
        dbt.date_spine(
            'day',
            "to_date('2000-01-01')",
            "to_date('2100-01-01')"
        )
    }}

),

final as (

    select cast(date_day as date) as date_day
    from days

)

select *
from final
