{{ config(alias='brand_generic_opportunity') }}
with alternatives as (
 select clinical_drug_id,min(clinical_drug_name) as generic_alternative_name,count(*) as generic_ndc_count,
 case when min(coalesce(generic_screening_basis,'active_product_flags'))=max(coalesce(generic_screening_basis,'active_product_flags'))
      then min(coalesce(generic_screening_basis,'active_product_flags')) else 'mixed_screening_basis' end as generic_screening_basis
 from {{ ref('drugs__generic_alternative') }} group by clinical_drug_id
), assessed as (
 select b.person_id,b.data_source,b.medication_id,b.drug_name,b.clinical_drug_id,b.clinical_drug_name,b.ndc_code as brand_ndc_code,
 a.generic_alternative_name,a.generic_screening_basis,
 coalesce(b.brand_screening_basis,'brand_flag') as brand_screening_basis,
 cast(case when b.brand_screening_basis='enterprise_nda_category'
                and a.generic_screening_basis='enterprise_marketing_metadata'
           then 1 else 0 end as {{ dbt.type_int() }}) as marketing_screening_applied_flag,
 b.payer,b.plan,b.dispensing_date,b.days_supply,b.quantity,b.paid_amount,b.supply_end_date,
 b.file_date as brand_file_date,b.ingest_datetime as brand_ingest_datetime,
 coalesce(a.generic_ndc_count,0) as generic_ndc_count,case when a.generic_ndc_count>0 then 1 else 0 end as generic_available_flag,
 g.benchmark_claim_count,g.benchmark_person_count,g.generic_paid_per_unit,
 g.benchmark_first_fill_date,g.benchmark_last_fill_date,g.benchmark_file_date,g.benchmark_ingest_datetime,
 p.assessment_date,p.patient_rx_freshness_date,p.patient_rx_freshness_basis,p.source_rx_freshness_date,p.source_rx_freshness_basis,
 p.source_clinical_lag_days,p.currently_enrolled_flag,p.outreach_readiness_status,
 case when coalesce(a.generic_ndc_count,0)=0 then 'no_catalog_generic'
 when b.paid_amount is null or b.paid_amount<=0 or b.quantity is null or b.quantity<=0 then 'unpriced_brand'
 when coalesce(g.benchmark_claim_count,0)<{{ var('drugs_generic_min_claims') }} or coalesce(g.benchmark_person_count,0)<{{ var('drugs_generic_min_people') }} then 'insufficient_paid_benchmark'
 else 'priced_for_review' end as pricing_status
 from {{ ref('drugs__current_brand') }} b join {{ ref('drugs__patient_context') }} p using(person_id,data_source)
 left join alternatives a on b.clinical_drug_id=a.clinical_drug_id
 left join {{ ref('drugs__generic_benchmark') }} g on b.person_id=g.person_id and b.data_source=g.data_source and b.clinical_drug_id=g.clinical_drug_id
 where p.deceased_flag=0
)
select {{ the_tuva_project.stable_id_hash(["'drugs_brand_generic_opportunity'",'person_id','data_source','clinical_drug_id']) }} as opportunity_id,*,
 case when pricing_status='priced_for_review' then round(paid_amount/days_supply*30,2) end as brand_paid_per_30_days,
 case when pricing_status='priced_for_review' then round(quantity/days_supply*30*generic_paid_per_unit,2) end as generic_paid_per_30_days,
 case when pricing_status='priced_for_review' then round(greatest(0,(paid_amount-quantity*generic_paid_per_unit)/days_supply*30),2) end as estimated_savings_per_30_days,
 case when pricing_status='priced_for_review' then round(greatest(0,(paid_amount-quantity*generic_paid_per_unit)/days_supply*365),2) end as estimated_annual_savings,
 '365 days at current utilization and observed payer-paid prices; before rebates; equivalence and coverage review required' as savings_basis
from assessed
