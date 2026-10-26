with packages as (
select cast(ndc11 as {{ dbt.type_string() }}) as ndc_code,
       cast(drug_id as {{ dbt.type_string() }}) as drug_id,
       {{ drugs_flag('is_brand') }} as brand_flag,
       {{ drugs_flag('active') }} as active_flag,
       {{ drugs_flag('prescribable') }} as prescribable_flag,
       {% if drugs_enterprise() %}
       marketing_category,case when (start_marketing_date is null or {{ drugs_vendor_date('start_marketing_date') }} is not null) and (end_marketing_date is null or {{ drugs_vendor_date('end_marketing_date') }} is not null) then 1 else 0 end as marketing_dates_valid_flag, {{ drugs_vendor_date('start_marketing_date') }} as start_marketing_date,
       {{ drugs_vendor_date('end_marketing_date') }} as end_marketing_date,
       row_number() over (partition by ndc11 order by price_start_date desc nulls last, drug_id) as row_number
       {% else %}
       cast(null as {{ dbt.type_string() }}) as marketing_category,
       1 as marketing_dates_valid_flag,cast(null as date) as start_marketing_date,cast(null as date) as end_marketing_date,
       row_number() over (partition by ndc11 order by drug_id) as row_number
       {% endif %}
from {{ drugs_coderx('packages') }}
)
select ndc_code,drug_id,brand_flag,active_flag,prescribable_flag,marketing_category,marketing_dates_valid_flag,start_marketing_date,end_marketing_date
from packages where row_number=1
