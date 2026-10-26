{{ config(alias='generic_alternative') }}
select p.ndc_code as generic_ndc_code,p.drug_id as generic_drug_id,d.drug_name as generic_drug_name,
 d.clinical_drug_id,d.clinical_drug_name,p.marketing_category,p.start_marketing_date,p.end_marketing_date,
 '{{ "active_anda_same_clinical_drug" if drugs_enterprise() else "active_nonbrand_same_clinical_drug" }}' as alternative_basis
from {{ ref('drugs__stg_packages') }} p join {{ ref('drugs__stg_drugs') }} d on p.drug_id=d.drug_id
where p.brand_flag=0 and p.active_flag=1 and p.prescribable_flag=1 and d.active_flag=1 and d.prescribable_flag=1
 and d.clinical_drug_id is not null
 {% if drugs_enterprise() %}
 and p.marketing_dates_valid_flag=1
 and upper(p.marketing_category) like 'ANDA%'
 and (p.start_marketing_date is null or p.start_marketing_date<={{ drugs_as_of() }})
 and (p.end_marketing_date is null or p.end_marketing_date>={{ drugs_as_of() }})
 {% endif %}
