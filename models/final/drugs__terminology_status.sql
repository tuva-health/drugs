{{ config(alias='terminology_status') }}
{% do drugs_validate_enterprise_contract() %}
{% set enterprise = drugs_enterprise() %}
select
    {{ drugs_as_of() }} as assessment_date,
    '{{ "enterprise" if enterprise else "open" }}' as terminology_tier,
    '{{ "enterprise_clinical_and_economics" if enterprise else "open_brand_generic_only" }}' as capability_status,
    cast({{ 1 if enterprise else 0 }} as {{ dbt.type_int() }}) as clinical_analytics_enabled_flag,
    cast({{ 1 if enterprise else 0 }} as {{ dbt.type_int() }}) as ingredient_episodes_enabled_flag,
    cast({{ 1 if enterprise else 0 }} as {{ dbt.type_int() }}) as enterprise_drug_details_enabled_flag,
    cast({{ 1 if enterprise else 0 }} as {{ dbt.type_int() }}) as enterprise_ingredients_enabled_flag,
    cast({{ 1 if enterprise else 0 }} as {{ dbt.type_int() }}) as enterprise_marketing_enabled_flag
