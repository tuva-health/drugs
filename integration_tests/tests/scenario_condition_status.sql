{{ config(tags=['drugs_scenarios']) }}
{% if drugs.drugs_enterprise() %}
-- Fixed expectations cover all seven diagnoses after Core's condition grouper,
-- including no treatment, unknown duration, deceased, and missing-feed cases.
with actual as (
 select s.*,m.claim_id as evidence_claim_id
 from {{ ref('drugs__condition_status') }} s
 left join {{ ref('drugs__medication') }} m
  on s.person_id=m.person_id and s.data_source=m.data_source
  and s.latest_maintenance_medication_id=m.medication_id
 where s.data_source in (select distinct data_source from {{ ref('scenario_people') }})
)
select e.person_id,e.data_source,e.condition_code
from {{ ref('expected_condition_status') }} e
left join actual a on e.person_id=a.person_id and e.data_source=a.data_source and e.condition_code=a.condition_code
where a.condition_status_id is null or a.condition_name<>e.condition_name
 or coalesce(a.open_drug_gap_flag,-1)<>coalesce(e.open_drug_gap_flag,-1)
 or coalesce(a.needs_refill_flag,-1)<>coalesce(e.needs_refill_flag,-1)
 or coalesce(a.estimated_refill_due_date,cast('1900-01-01' as date))<>coalesce(e.estimated_refill_due_date,cast('1900-01-01' as date))
 or coalesce(a.evidence_claim_id,'missing')<>coalesce(e.evidence_claim_id,'missing')
 or a.condition_file_date is null or a.condition_file_date<>cast('2026-11-10' as date)
union all
select a.person_id,a.data_source,a.condition_code
from actual a left join {{ ref('expected_condition_status') }} e
 on e.person_id=a.person_id and e.data_source=a.data_source and e.condition_code=a.condition_code
where e.person_id is null

{% else %}
-- Disabled clinical features remain empty, including after partial rebuilds.
select 'condition_status' as unexpectedly_populated_relation from {{ ref('drugs__condition_status') }}
union all
select 'medication_condition' as unexpectedly_populated_relation from {{ ref('drugs__medication_condition') }}
union all
select 'open_drug_gap' as unexpectedly_populated_relation from {{ ref('drugs__open_drug_gap') }}
union all
select 'needs_refill' as unexpectedly_populated_relation from {{ ref('drugs__needs_refill') }}
{% endif %}
