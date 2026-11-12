{% macro drugs_enterprise_required_columns() %}
  {{ return({
      'packages': ['ndc11', 'drug_id', 'is_brand', 'active', 'prescribable',
                   'marketing_category', 'start_marketing_date', 'end_marketing_date'],
      'drugs': ['drug_id', 'drug_name', 'clinical_drug_id', 'clinical_drug_name',
                'is_brand', 'active', 'prescribable', 'ingredient_id', 'ingredient_name',
                'ingredient_type', 'dose_form_id', 'dose_form_name'],
      'classes': ['drug_id', 'atc_1_code', 'atc_1_name', 'atc_2_code', 'atc_2_name',
                  'atc_3_code', 'atc_3_name', 'atc_4_code', 'atc_4_name']
  }) }}
{% endmacro %}

{% macro drugs_validate_enterprise_relation(table) %}
  {% if not drugs_enterprise() or not execute %}{{ return('') }}{% endif %}
  {% set required = drugs_enterprise_required_columns()[table] %}
  {% set relation = source('coderx_enterprise', table) %}
  {% set existing = adapter.get_relation(database=relation.database, schema=relation.schema, identifier=relation.identifier) %}
  {% if existing is none %}
    {{ exceptions.raise_compiler_error(
        'Drugs CodeRx Enterprise requires relation ' ~ relation ~ '. Load the licensed CodeRx ' ~ table ~
        ' table and grant the dbt role access, or set use_coderx_enterprise: false for Open drug gaps, refills, and Brand vs. Generic. Drug Episodes require Enterprise.'
    ) }}
  {% endif %}
  {% set names = [] %}
  {% for column in adapter.get_columns_in_relation(existing) %}
    {% do names.append(column.name | lower) %}
  {% endfor %}
  {% set missing = [] %}
  {% for column in required %}
    {% if column not in names %}{% do missing.append(column) %}{% endif %}
  {% endfor %}
  {% if missing | length > 0 %}
    {{ exceptions.raise_compiler_error(
        'Drugs CodeRx Enterprise relation ' ~ relation ~ ' is missing required columns: ' ~ (missing | join(', ')) ~
        '. Expose these fields from the licensed CodeRx delivery. Core-only projections may not contain all fields needed by Drugs.'
    ) }}
  {% endif %}
  {{ return('') }}
{% endmacro %}

{% macro drugs_validate_enterprise_contract() %}
  {% if drugs_enterprise() %}
    {% for table in drugs_enterprise_required_columns() %}
      {% do drugs_validate_enterprise_relation(table) %}
    {% endfor %}
  {% endif %}
  {{ return('') }}
{% endmacro %}

{% macro drugs_enterprise_drug_details_enabled() %}
  {{ return(drugs_enterprise()) }}
{% endmacro %}

{% macro drugs_enterprise_marketing_enabled() %}
  {{ return(drugs_enterprise()) }}
{% endmacro %}
