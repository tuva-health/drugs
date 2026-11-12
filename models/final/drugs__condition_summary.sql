{{ config(alias='condition_summary') }}
-- Annual gap counts cover all 68 conditions. The separate refill denominator
-- covers only the seven chronic conditions, including uncertain/no-fill patients.
with counts as (
 select assessment_date,data_source,condition_code,condition_name,condition_family,
 max(refill_condition_eligible_flag) as refill_condition_eligible_flag,count(*) as assessed_patients,
 sum(case when open_drug_gap_flag=1 then 1 else 0 end) as patients_with_open_gaps,
 sum(case when qualifying_condition_fill_count>0 then 1 else 0 end) as patients_with_qualifying_dispensing,
 sum(case when needs_refill_flag=1 then 1 else 0 end) as patients_needing_refill,
 sum(case when open_drug_gap_flag is null then 1 else 0 end) as gap_unassessable_patients,
 sum(case when refill_condition_eligible_flag=1 and needs_refill_flag is null then 1 else 0 end) as refill_unassessable_patients,
 sum(case when refill_condition_eligible_flag=1 and deceased_flag=0 and source_latest_fill_date is not null then 1 else 0 end) as refill_denominator_patients,
 sum(case when open_drug_gap_flag=1 and outreach_readiness_status='current_record_review' then 1 else 0 end) as current_record_gap_patients,
 sum(case when needs_refill_flag=1 and outreach_readiness_status='current_record_review' then 1 else 0 end) as current_record_refill_patients
 from {{ ref('drugs__condition_status') }}
 group by assessment_date,data_source,condition_code,condition_name,condition_family
)
select *,round(100.0*patients_needing_refill/nullif(refill_denominator_patients,0),2) as percent_needing_refill
from counts
