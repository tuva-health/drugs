{{ config(tags=['drugs_scenarios']) }}
{% if drugs.drugs_enterprise() %}
select e.data_source,e.condition_code
from {{ ref('expected_condition_summary') }} e
left join {{ ref('drugs__condition_summary') }} a
 on e.data_source=a.data_source and e.condition_code=a.condition_code
where a.condition_code is null
 or a.assessed_patients<>e.assessed_patients
 or a.patients_with_open_gaps<>e.patients_with_open_gaps
 or a.patients_needing_refill<>e.patients_needing_refill
 or a.refill_denominator_patients<>e.refill_denominator_patients
 or coalesce(a.percent_needing_refill,-1)<>coalesce(e.percent_needing_refill,-1)
 or a.gap_unassessable_patients<>e.gap_unassessable_patients
 or a.refill_unassessable_patients<>e.refill_unassessable_patients

{% else %}
-- Disabled clinical features remain empty, including after partial rebuilds.
select 'condition_summary' as unexpectedly_populated_relation from {{ ref('drugs__condition_summary') }}
{% endif %}
