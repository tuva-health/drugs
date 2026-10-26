{% macro drugs_optional_column(relation, column, alias, type) %}
 {% set names = [] %}
 {% if execute %}
  {% for c in adapter.get_columns_in_relation(relation) %}{% do names.append(c.name | lower) %}{% endfor %}
 {% endif %}
 {% if column | lower in names %}cast({{ alias }}.{{ column }} as {{ type }}){% else %}cast(null as {{ type }}){% endif %}
{% endmacro %}
