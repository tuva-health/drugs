with ranked as (
 select *,row_number() over(partition by person_id,data_source,condition_code
 order by case when refill_eligible_flag=1 and exposure_status='usable' and supply_end_date is not null then 0 else 1 end,
 supply_end_date desc,dispensing_date desc,medication_id desc) as latest_rank
 from {{ ref('drugs__medication_condition') }}
)
select person_id,data_source,condition_code,count(*) as prior_condition_fill_count,
 max(active_supply_flag) as active_condition_supply_flag,
 max(case when refill_eligible_flag=1 and exposure_status='usable' then active_supply_flag else 0 end) as active_maintenance_supply_flag,
 max(case when dispensing_date>={{ dbt.dateadd('day',-var('drugs_uncertain_exposure_days')+1,drugs_as_of()) }} and exposure_status<>'usable' then 1 else 0 end) as unknown_duration_flag,
 -- The due date and displayed evidence must describe the same maintenance fill.
 max(case when latest_rank=1 and refill_eligible_flag=1 and exposure_status='usable' and supply_end_date is not null then supply_end_date end) as maintenance_supply_end_date,
 count(distinct case when refill_eligible_flag=1 and exposure_status='usable' and dispensing_date>={{ dbt.dateadd('day',-var('drugs_condition_lookback_days')+1,drugs_as_of()) }} then dispensing_date end) as maintenance_fill_dates,
 max(case when latest_rank=1 and refill_eligible_flag=1 and exposure_status='usable' and supply_end_date is not null then medication_id end) as latest_maintenance_medication_id,
 max(case when latest_rank=1 and refill_eligible_flag=1 and exposure_status='usable' and supply_end_date is not null then drug_name end) as latest_maintenance_drug_name,
 max(file_date) as treatment_evidence_file_date,max(ingest_datetime) as treatment_evidence_ingest_datetime
from ranked group by person_id,data_source,condition_code
