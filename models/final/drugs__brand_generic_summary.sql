{{ config(alias='brand_generic_summary') }}
-- Aggregate the patient/product parent, never the one-to-many NDC alternatives.
select assessment_date,data_source,drug_name as brand_drug,clinical_drug_id,
 generic_alternative_name as generic_alternative,count(*) as patients_who_could_switch,
 sum(case when pricing_status='priced_for_review' then 1 else 0 end) as patients_with_savings_estimate,
 sum(case when pricing_status<>'priced_for_review' then 1 else 0 end) as patients_without_savings_estimate,
 sum(case when estimated_annual_savings>0 then 1 else 0 end) as patients_with_positive_estimated_savings,
 sum(estimated_annual_savings) as annual_savings_for_priced_patients,
 case when sum(case when pricing_status<>'priced_for_review' then 1 else 0 end)=0
 then sum(estimated_annual_savings) end as annual_savings_if_all_switched,
 case when sum(case when pricing_status<>'priced_for_review' then 1 else 0 end)=0
 then 'all_patients_priced' else 'incomplete_pricing' end as savings_coverage_status
from {{ ref('drugs__brand_generic_opportunity') }} where generic_available_flag=1
group by assessment_date,data_source,drug_name,clinical_drug_id,generic_alternative_name
