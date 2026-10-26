{{ config(alias='condition_summary') }}
-- One row per source/condition, including zero flagged patients.
select assessment_date,data_source,condition_code,condition_name,count(*) as assessed_patients,
 sum(case when open_drug_gap_flag=1 then 1 else 0 end) as patients_with_open_gaps,
 sum(case when needs_refill_flag=1 then 1 else 0 end) as patients_needing_refill,
 sum(case when open_drug_gap_flag is null then 1 else 0 end) as gap_unassessable_patients,
 sum(case when needs_refill_flag is null then 1 else 0 end) as refill_unassessable_patients,
 sum(case when open_drug_gap_flag=1 and outreach_readiness_status='current_record_review' then 1 else 0 end) as current_record_gap_patients,
 sum(case when needs_refill_flag=1 and outreach_readiness_status='current_record_review' then 1 else 0 end) as current_record_refill_patients
from {{ ref('drugs__condition_status') }}
group by assessment_date,data_source,condition_code,condition_name
