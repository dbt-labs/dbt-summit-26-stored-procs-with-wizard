{% macro call_legacy_order_profitability() %}
    {% set procedure_call %}
        call {{ target.database }}.{{ target.schema }}.SP_LOAD_ORDER_PROFITABILITY()
    {% endset %}

    {% if execute %}
        {% set result = run_query(procedure_call) %}

        {% if result is not none and result.rows | length > 0 %}
            {{ log(result.rows[0][0], info=true) }}
        {% endif %}
    {% endif %}
{% endmacro %}
