{{ config(alias='terminology_status') }}
{% set details = drugs_enterprise_drug_details_enabled() %}
{% set ingredients = drugs_enterprise_ingredients_enabled() %}
{% set marketing = drugs_enterprise_marketing_enabled() %}
select
    {{ drugs_as_of() }} as assessment_date,
    '{{ "enterprise" if drugs_enterprise() else "open" }}' as terminology_tier,
    '{% if not drugs_enterprise() %}open_baseline{% elif not drugs_enterprise_enrichment_enabled() %}enterprise_enrichment_disabled{% elif details and ingredients and marketing %}enterprise_enriched{% elif details or ingredients or marketing %}enterprise_partially_enriched{% else %}enterprise_base_only{% endif %}' as capability_status,
    cast({{ 1 if details else 0 }} as {{ dbt.type_int() }}) as enterprise_drug_details_enabled_flag,
    cast({{ 1 if ingredients else 0 }} as {{ dbt.type_int() }}) as enterprise_ingredients_enabled_flag,
    cast({{ 1 if marketing else 0 }} as {{ dbt.type_int() }}) as enterprise_marketing_enabled_flag,
    '{{ var("drugs_data_asset_version") }}' as public_ingredient_asset_version
