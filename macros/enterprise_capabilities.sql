{% macro drugs_enterprise_enrichment_enabled() %}
  {% set enabled = var('drugs_enable_enterprise_enrichment', true) %}
  {% if enabled is not boolean %}
    {{ exceptions.raise_compiler_error('drugs_enable_enterprise_enrichment must be an unquoted YAML boolean') }}
  {% endif %}
  {{ return(drugs_enterprise() and enabled) }}
{% endmacro %}

{% macro drugs_relation_has_columns(relation, required_columns) %}
  {% if not execute %}{{ return(false) }}{% endif %}
  {% set existing = adapter.get_relation(database=relation.database, schema=relation.schema, identifier=relation.identifier) %}
  {% if existing is none %}{{ return(false) }}{% endif %}
  {% set names = [] %}
  {% for column in adapter.get_columns_in_relation(existing) %}
    {% do names.append(column.name | lower) %}
  {% endfor %}
  {% for required in required_columns %}
    {% if required | lower not in names %}{{ return(false) }}{% endif %}
  {% endfor %}
  {{ return(true) }}
{% endmacro %}

{% macro drugs_has_enterprise_drug_columns() %}
  {{ return(drugs_relation_has_columns(source('coderx_enterprise', 'drugs'),
      ['ingredient_id', 'ingredient_name', 'dose_form_name'])) }}
{% endmacro %}

{% macro drugs_has_enterprise_marketing_columns() %}
  {{ return(drugs_relation_has_columns(source('coderx_enterprise', 'packages'),
      ['marketing_category', 'start_marketing_date', 'end_marketing_date'])) }}
{% endmacro %}

{% macro drugs_has_enterprise_ingredient_columns() %}
  {{ return(drugs_relation_has_columns(source('coderx_enterprise', 'ingredients'),
      ['drug_id', 'ingredient_component_id', 'ingredient_component_name', 'ingredient_component_type'])) }}
{% endmacro %}

{% macro drugs_enterprise_drug_details_enabled() %}
  {{ return(drugs_enterprise_enrichment_enabled() and drugs_has_enterprise_drug_columns()) }}
{% endmacro %}

{% macro drugs_enterprise_marketing_enabled() %}
  {{ return(drugs_enterprise_enrichment_enabled() and drugs_has_enterprise_marketing_columns()) }}
{% endmacro %}

{% macro drugs_enterprise_ingredients_enabled() %}
  {{ return(drugs_enterprise_enrichment_enabled() and drugs_has_enterprise_ingredient_columns()) }}
{% endmacro %}
