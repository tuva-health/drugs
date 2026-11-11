{% set details = drugs_enterprise_drug_details_enabled() %}
select
    cast(drug_id as {{ dbt.type_string() }}) as drug_id,
    drug_name,
    cast(clinical_drug_id as {{ dbt.type_string() }}) as clinical_drug_id,
    clinical_drug_name,
    {{ drugs_flag('is_brand') }} as brand_flag,
    {{ drugs_flag('active') }} as active_flag,
    {{ drugs_flag('prescribable') }} as prescribable_flag,
    {% if details %}
    cast(ingredient_id as {{ dbt.type_string() }}) as ingredient_id,
    {{ drugs_ingredient_set_key('ingredient_id') }} as therapy_ingredient_id,
    ingredient_name,
    dose_form_name,
    {% else %}
    cast(null as {{ dbt.type_string() }}) as ingredient_id,
    cast(null as {{ dbt.type_string() }}) as therapy_ingredient_id,
    cast(null as {{ dbt.type_string() }}) as ingredient_name,
    cast(null as {{ dbt.type_string() }}) as dose_form_name,
    {% endif %}
    cast({{ 1 if details else 0 }} as {{ dbt.type_int() }}) as enterprise_drug_details_enabled_flag,
    '{{ "enterprise" if drugs_enterprise() else "open" }}' as terminology_tier
from {{ drugs_coderx('drugs') }}
