{{ config(tags=['drugs_scenarios']) }}
-- ($120 - $9 + $90 - $9) / 30 * 365 = $2,336/year for the two
-- priced candidates. The source without generic claims must stay unpriced.
with expected as (
 select 'scenario_economics' as data_source,2 as candidates,2 as priced,
  cast(2336 as {{ dbt.type_numeric() }}) as annual_savings
 union all
 select 'scenario_economics_other',1,0,cast(null as {{ dbt.type_numeric() }})
)
select e.data_source
from expected e left join {{ ref('drugs__brand_generic_summary') }} a
 on e.data_source=a.data_source and a.clinical_drug_id='617310'
where a.clinical_drug_id is null or a.patients_who_could_switch<>e.candidates
 or a.patients_with_savings_estimate<>e.priced
 or abs(coalesce(a.annual_savings_if_all_switched,-1)-coalesce(e.annual_savings,-1))>0.00001
 or abs(coalesce(a.annual_savings_for_priced_patients,-1)-coalesce(e.annual_savings,-1))>0.00001
