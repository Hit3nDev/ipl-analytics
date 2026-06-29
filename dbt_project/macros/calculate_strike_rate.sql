-- macros/calculate_strike_rate.sql
--
-- Calculates batting strike rate: (runs / balls) × 100
-- Returns null if balls = 0 to avoid division errors.
-- Uses dbt_utils.safe_divide under the hood.

{% macro calculate_strike_rate(runs_col, balls_col) %}
    round(
        {{ dbt_utils.safe_divide(runs_col ~ ' * 100.0', balls_col) }},
        2
    )
{% endmacro %}
