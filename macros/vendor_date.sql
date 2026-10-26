{% macro drugs_vendor_date(column) %}
 try_cast(case when length(trim(cast({{ column }} as {{ dbt.type_string() }})))=8
 then concat(substr(cast({{ column }} as {{ dbt.type_string() }}),1,4),'-',substr(cast({{ column }} as {{ dbt.type_string() }}),5,2),'-',substr(cast({{ column }} as {{ dbt.type_string() }}),7,2))
 else cast({{ column }} as {{ dbt.type_string() }}) end as date)
{% endmacro %}
