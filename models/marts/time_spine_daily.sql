{{ config(materialized='table') }}

with generated_dates as (

    select
        dateadd(
            day,
            row_number() over (order by seq4()) - 1,
            '2020-01-01'::date
        )::date as date_day
    from table(generator(rowcount => 5500))

),

final as (

    select date_day
    from generated_dates
    where date_day < '2035-01-01'::date

)

select *
from final
