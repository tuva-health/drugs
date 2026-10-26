{{ config(alias='condition_status') }}
with conditions as (
 select c.person_id,c.data_source,r.condition_code,c.condition_name,min(c.condition_date) as first_condition_date,
 max(c.condition_date) as last_condition_date,count(*) as condition_evidence_count,
 max(c.file_date) as condition_file_date,max(c.ingest_datetime) as condition_ingest_datetime
 from {{ ref('drugs__condition_evidence') }} c join (select distinct condition_code,condition_name from {{ ref('drugs__condition_rule') }}) r using(condition_name)
 group by c.person_id,c.data_source,r.condition_code,c.condition_name
), facts as (
 select p.*,c.condition_code,c.condition_name,c.first_condition_date,c.last_condition_date,c.condition_evidence_count,
 c.condition_file_date,c.condition_ingest_datetime,
 coalesce(c.condition_file_date,cast(c.condition_ingest_datetime as date)) as condition_freshness_date,
 case when c.condition_file_date is not null then 'file_date' when c.condition_ingest_datetime is not null then 'ingest_datetime' else 'unavailable' end as condition_freshness_basis,
 coalesce(m.prior_condition_fill_count,0) as prior_condition_fill_count,
 coalesce(m.active_condition_supply_flag,0) as active_condition_supply_flag,coalesce(m.unknown_duration_flag,0) as unknown_duration_flag,
 m.maintenance_supply_end_date,cast({{ dbt.dateadd('day',1,'m.maintenance_supply_end_date') }} as date) as estimated_refill_due_date,
 coalesce(m.maintenance_fill_dates,0) as maintenance_fill_dates,m.latest_maintenance_medication_id,m.latest_maintenance_drug_name,
 m.treatment_evidence_file_date,m.treatment_evidence_ingest_datetime
 from conditions c join {{ ref('drugs__patient_context') }} p using(person_id,data_source)
 left join {{ ref('drugs__condition_medication_summary') }} m on c.person_id=m.person_id and c.data_source=m.data_source and c.condition_code=m.condition_code
), assessed as (
 select *,case when deceased_flag=1 then 'excluded_deceased'
 when active_condition_supply_flag=1 then 'active_supply_observed'
 when source_latest_fill_date is null then 'unable_to_assess_pharmacy_feed'
 when unknown_duration_flag=1 then 'unable_to_assess_days_supply'
 when recent_unmapped_drug_flag=1 then 'unable_to_assess_unmapped_drug'
 else 'potential_open_drug_gap' end as gap_status,
 {{ dbt.datediff('estimated_refill_due_date','assessment_date','day') }} as days_overdue
 from facts
)
select {{ dbt_utils.generate_surrogate_key(['person_id','data_source','condition_code']) }} as condition_status_id,*,
 cast(case when gap_status='potential_open_drug_gap' then 1 when gap_status like 'unable_to_assess%' then null else 0 end as {{ dbt.type_int() }}) as open_drug_gap_flag,
 cast(case when deceased_flag=1 then 0 when source_latest_fill_date is null or unknown_duration_flag=1 or recent_unmapped_drug_flag=1 then null
 when maintenance_fill_dates>={{ var('drugs_refill_min_fills') }}
 and days_overdue between -{{ var('drugs_refill_lookahead_days') }} and {{ var('drugs_refill_max_overdue_days') }}
 and (active_condition_supply_flag=0 or days_overdue<0) then 1 else 0 end as {{ dbt.type_int() }}) as needs_refill_flag,
 case when prior_condition_fill_count=0 then 'no_prior_qualifying_claim' else 'prior_treatment_now_without_active_supply' end as gap_history
from assessed
