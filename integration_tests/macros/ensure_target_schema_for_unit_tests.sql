{# Unit tests can create temporary relations in target.schema even when all
   ordinary models have explicit prefixed schemas. #}
{% macro drugs_test_target_schema() -%}
  {%- if execute -%}
    {%- do adapter.create_schema(api.Relation.create(database=target.database, schema=target.schema)) -%}
  {%- endif -%}
{%- endmacro %}
