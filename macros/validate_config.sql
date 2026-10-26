{% macro drugs_validate_config() %}
 {% for name in ['drugs_episode_gap_days','drugs_refill_lookahead_days','drugs_refill_max_overdue_days'] %}
 {% set value=var(name) %}{% if value is not integer or value<0 %}{{ exceptions.raise_compiler_error(name ~ ' must be a nonnegative integer') }}{% endif %}
 {% endfor %}
 {% for name in ['drugs_condition_lookback_days','drugs_uncertain_exposure_days','drugs_refill_min_fills','drugs_freshness_days','drugs_generic_lookback_days','drugs_generic_min_claims','drugs_generic_min_people'] %}
 {% set value=var(name) %}{% if value is not integer or value<1 %}{{ exceptions.raise_compiler_error(name ~ ' must be a positive integer') }}{% endif %}
 {% endfor %}
 {{ return('select 1') }}
{% endmacro %}
