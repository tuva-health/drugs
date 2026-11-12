{{ config(alias='terminology_status') }}
{% do drugs_validate_enterprise_contract() %}
{% set enterprise = drugs_enterprise() %}
select
    {{ drugs_as_of() }} as assessment_date,
    '{{ "enterprise" if enterprise else "open" }}' as terminology_tier,
    '{{ "enterprise_episodes_and_broader_terminology" if enterprise else "open_gaps_refills_and_brand_generic" }}' as capability_status,
    cast(1 as {{ dbt.type_int() }}) as clinical_analytics_enabled_flag,
    cast(1 as {{ dbt.type_int() }}) as drug_gaps_enabled_flag,
    cast(1 as {{ dbt.type_int() }}) as needs_refill_enabled_flag,
    cast(1 as {{ dbt.type_int() }}) as brand_generic_enabled_flag,
    cast({{ 1 if enterprise else 0 }} as {{ dbt.type_int() }}) as drug_episodes_enabled_flag,
    cast({{ 1 if enterprise else 0 }} as {{ dbt.type_int() }}) as enterprise_drug_details_enabled_flag,
    cast({{ 1 if enterprise else 0 }} as {{ dbt.type_int() }}) as enterprise_marketing_enabled_flag
