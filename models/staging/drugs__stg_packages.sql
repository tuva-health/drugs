{% do drugs_validate_enterprise_relation('packages') %}
{% set marketing = drugs_enterprise_marketing_enabled() %}
with packages as (
    select
        cast(ndc11 as {{ dbt.type_string() }}) as ndc_code,
        cast(drug_id as {{ dbt.type_string() }}) as drug_id,
        {{ drugs_flag('is_brand') }} as brand_flag,
        {{ drugs_flag('active') }} as active_flag,
        {{ drugs_flag('prescribable') }} as prescribable_flag,
        cast({{ 1 if marketing else 0 }} as {{ dbt.type_int() }}) as enterprise_marketing_enabled_flag,
        {% if marketing %}
        nullif(trim(cast(marketing_category as {{ dbt.type_string() }})), '') as marketing_category,
        case when (start_marketing_date is null or {{ drugs_vendor_date('start_marketing_date') }} is not null)
                  and (end_marketing_date is null or {{ drugs_vendor_date('end_marketing_date') }} is not null)
             then 1 else 0 end as marketing_dates_valid_flag,
        {{ drugs_vendor_date('start_marketing_date') }} as start_marketing_date,
        {{ drugs_vendor_date('end_marketing_date') }} as end_marketing_date
        {% else %}
        cast(null as {{ dbt.type_string() }}) as marketing_category,
        1 as marketing_dates_valid_flag,
        cast(null as date) as start_marketing_date,
        cast(null as date) as end_marketing_date
        {% endif %}
    from {{ drugs_coderx('packages') }}
)
-- Collapse identical projected rows only. Conflicting NDC mappings remain
-- visible to the staging uniqueness test instead of choosing a drug or flag.
select distinct
    ndc_code, drug_id, brand_flag, active_flag, prescribable_flag,
    marketing_category, marketing_dates_valid_flag, start_marketing_date, end_marketing_date,
    enterprise_marketing_enabled_flag,
    cast(case when enterprise_marketing_enabled_flag = 1 and marketing_category is not null
              then 1 else 0 end as {{ dbt.type_int() }}) as marketing_screening_applied_flag
from packages
