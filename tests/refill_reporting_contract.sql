-- Check the published denominator against the patient-level population;
-- uncertain/no-treatment patients remain included within observed feeds.
with population as (
 select assessment_date,data_source,condition_code,
 sum(case when deceased_flag=0 and source_latest_fill_date is not null then 1 else 0 end) as denominator,
 sum(case when deceased_flag=0 and source_latest_fill_date is not null and needs_refill_flag=1 then 1 else 0 end) as numerator
 from {{ ref('drugs__condition_status') }}
 group by assessment_date,data_source,condition_code
)
select s.data_source,s.condition_code
from {{ ref('drugs__condition_summary') }} s
join population p on s.assessment_date=p.assessment_date and s.data_source=p.data_source and s.condition_code=p.condition_code
where s.refill_denominator_patients<>p.denominator
 or s.patients_needing_refill<>p.numerator
 or s.patients_needing_refill>s.refill_denominator_patients
 or (p.denominator=0 and s.percent_needing_refill is not null)
 or (p.denominator>0 and (s.percent_needing_refill is null
  or abs(s.percent_needing_refill-round(100.0*p.numerator/p.denominator,2))>0.00001))
