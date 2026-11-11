{{ config(tags=['drugs_scenarios']) }}
-- Four generic claims among three people have a median payer-paid unit price
-- of $0.30. A newer generic removes the switched patient's older brand fill.
with actual as (
 select * from {{ ref('drugs__brand_generic_opportunity') }}
 where data_source in ('scenario_economics','scenario_economics_other')
)
select e.person_id,e.data_source
from {{ ref('expected_brand_opportunities') }} e
left join actual a on e.person_id=a.person_id and e.data_source=a.data_source and e.clinical_drug_id=a.clinical_drug_id
where a.opportunity_id is null or a.pricing_status<>e.pricing_status
 or a.generic_available_flag<>1
 or coalesce(a.benchmark_claim_count,-1)<>coalesce(e.benchmark_claim_count,-1)
 or coalesce(a.benchmark_person_count,-1)<>coalesce(e.benchmark_person_count,-1)
 or abs(coalesce(a.generic_paid_per_unit,-1)-coalesce(e.generic_paid_per_unit,-1))>0.00001
 or abs(coalesce(a.estimated_savings_per_30_days,-1)-coalesce(e.estimated_savings_per_30_days,-1))>0.00001
 or abs(coalesce(a.estimated_annual_savings,-1)-coalesce(e.estimated_annual_savings,-1))>0.00001
union all
select a.person_id,a.data_source
from actual a left join {{ ref('expected_brand_opportunities') }} e
 on e.person_id=a.person_id and e.data_source=a.data_source and e.clinical_drug_id=a.clinical_drug_id
where e.person_id is null
