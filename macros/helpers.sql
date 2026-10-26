{% macro drugs_enterprise() %}
  {% set value = var('use_coderx_enterprise', false) %}
  {% if value is not boolean %}
    {{ exceptions.raise_compiler_error('use_coderx_enterprise must be an unquoted YAML boolean') }}
  {% endif %}
  {{ return(value) }}
{% endmacro %}

{% macro drugs_coderx(table) %}
  {{ return(source('coderx_enterprise' if drugs_enterprise() else 'coderx_open', table)) }}
{% endmacro %}

{% macro drugs_flag(column) %}
  cast(case when lower(cast({{ column }} as {{ dbt.type_string() }})) in ('true','1') then 1
            when lower(cast({{ column }} as {{ dbt.type_string() }})) in ('false','0') then 0 end as {{ dbt.type_int() }})
{% endmacro %}

{% macro drugs_as_of() %}
  {% if var('drugs_as_of_date', none) %}
    cast('{{ var("drugs_as_of_date") }}' as date)
  {% else %}
    cast(current_timestamp as date)
  {% endif %}
{% endmacro %}

{% macro drugs_float_type() %}
  {# Spark FLOAT is 32-bit; decomposition must retain cent-level reconciliation. #}
  {{ return('double' if target.type in ['databricks', 'spark'] else dbt.type_float()) }}
{% endmacro %}

{% macro drugs_ingredient_set_key(column) %}
  {# Vendor pack lists can reorder/repeat concept IDs between releases.
     Therapy identity is an unordered set; stockpiling still uses clinical product. #}
  {% if target.type in ['databricks', 'spark'] %}
    nullif(array_join(array_sort(array_distinct(split(replace({{ column }}, ' ', ''), '[|]'))), ' | '), '')
  {% else %}
    nullif(array_to_string(array_sort(array_distinct(split(replace({{ column }}, ' ', ''), '|'))), ' | '), '')
  {% endif %}
{% endmacro %}
