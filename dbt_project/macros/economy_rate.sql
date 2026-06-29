-- macros/economy_rate.sql
--
-- Calculates bowling economy rate: (runs_conceded / balls_bowled) × 6
-- Standard T20 cricket metric: runs per over.

{% macro economy_rate(runs_col, balls_col) %}
    round(
        {{ dbt_utils.safe_divide(runs_col ~ ' * 6.0', balls_col) }},
        2
    )
{% endmacro %}


-- macros/safe_divide.sql
-- Wrapper — dbt_utils already provides this, but we alias it
-- so models don't need to remember the full package path.

{% macro safe_divide(numerator, denominator) %}
    {{ dbt_utils.safe_divide(numerator, denominator) }}
{% endmacro %}
