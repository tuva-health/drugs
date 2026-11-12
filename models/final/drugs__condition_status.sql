{{ config(alias='condition_status') }}
with policy as (
 select condition_code,condition_name,max(condition_family) as condition_family,
 max(refill_eligible_flag) as refill_condition_eligible_flag
 from {{ ref('drugs__condition_rule') }} group by condition_code,condition_name
), conditions as (
 select c.person_id,c.data_source,r.condition_code,c.condition_name,r.condition_family,r.refill_condition_eligible_flag,
 min(c.condition_date) as first_condition_date,max(c.condition_date) as last_condition_date,
 count(*) as condition_evidence_count,max(c.file_date) as condition_file_date,max(c.ingest_datetime) as condition_ingest_datetime
 from {{ ref('drugs__condition_evidence') }} c join policy r on c.condition_name=r.condition_name
 group by c.person_id,c.data_source,r.condition_code,c.condition_name,r.condition_family,r.refill_condition_eligible_flag
), classified_products as (
 select drug_id,max(case when atc_4_code is not null then 1 else 0 end) as complete_class_flag
 from {{ ref('drugs__stg_classes') }}
 where coalesce(atc_4_code,atc_3_code,atc_2_code,atc_1_code) is not null
 group by drug_id
), class_quality as (
 select d.drug_id,coalesce(p.complete_class_flag,c.complete_class_flag,0) as complete_class_flag
 from {{ ref('drugs__stg_drugs') }} d
 left join classified_products p on d.drug_id=p.drug_id
 left join classified_products c on d.clinical_drug_id=c.drug_id
), annual_quality as (
 -- An undated dispensing cannot safely be declared outside the annual window.
 -- Unmapped records are patient/source uncertainty, not condition-specific absence.
 select m.person_id,m.data_source,
 max(case when m.dispensing_date is null or coalesce(q.complete_class_flag,0)=0 then 1 else 0 end) as annual_unknown_medication_flag,
 sum(case when m.dispensing_date is null then 1 else 0 end) as undated_medication_count,
 sum(case when coalesce(q.complete_class_flag,0)=0 then 1 else 0 end) as annual_unmapped_medication_count,
 max(case when m.dispensing_date is null or coalesce(q.complete_class_flag,0)=0 then m.file_date end) as uncertain_evidence_file_date,
 max(case when m.dispensing_date is null or coalesce(q.complete_class_flag,0)=0 then m.ingest_datetime end) as uncertain_evidence_ingest_datetime
 from {{ ref('drugs__medication') }} m left join class_quality q on m.drug_id=q.drug_id
 where m.dispensing_date is null or m.dispensing_date between {{ dbt.dateadd('day',-364,drugs_as_of()) }} and {{ drugs_as_of() }}
 group by m.person_id,m.data_source
), facts as (
 select p.*,c.condition_code,c.condition_name,c.condition_family,c.refill_condition_eligible_flag,
 c.first_condition_date,c.last_condition_date,c.condition_evidence_count,c.condition_file_date,c.condition_ingest_datetime,
 coalesce(c.condition_file_date,cast(c.condition_ingest_datetime as date)) as condition_freshness_date,
 case when c.condition_file_date is not null then 'file_date' when c.condition_ingest_datetime is not null then 'ingest_datetime' else 'unavailable' end as condition_freshness_basis,
 coalesce(m.prior_condition_fill_count,0) as prior_condition_fill_count,
 coalesce(m.qualifying_condition_fill_count,0) as qualifying_condition_fill_count,
 coalesce(m.possible_condition_fill_count,0) as possible_condition_fill_count,
 coalesce(m.active_condition_supply_flag,0) as active_condition_supply_flag,
 coalesce(m.active_maintenance_supply_flag,0) as active_maintenance_supply_flag,
 coalesce(m.unknown_duration_flag,0) as unknown_duration_flag,
 coalesce(m.possible_refill_mapping_flag,0) as possible_refill_mapping_flag,
 coalesce(q.annual_unknown_medication_flag,0) as annual_unknown_medication_flag,
 coalesce(q.undated_medication_count,0) as undated_medication_count,
 coalesce(q.annual_unmapped_medication_count,0) as annual_unmapped_medication_count,
 q.uncertain_evidence_file_date,q.uncertain_evidence_ingest_datetime,
 m.maintenance_supply_end_date,cast({{ dbt.dateadd('day',1,'m.maintenance_supply_end_date') }} as date) as estimated_refill_due_date,
 coalesce(m.maintenance_fill_dates,0) as maintenance_fill_dates,
 m.latest_maintenance_medication_id,m.latest_maintenance_drug_name,m.latest_maintenance_therapy_id,m.latest_maintenance_dispensing_date,m.refill_class_confidence,
 m.treatment_evidence_file_date,m.treatment_evidence_ingest_datetime
 from conditions c join {{ ref('drugs__patient_context') }} p on c.person_id=p.person_id and c.data_source=p.data_source
 left join {{ ref('drugs__condition_medication_summary') }} m
   on c.person_id=m.person_id and c.data_source=m.data_source and c.condition_code=m.condition_code
 left join annual_quality q on c.person_id=q.person_id and c.data_source=q.data_source
), gap_assessed as (
 select *,case when deceased_flag=1 then 'excluded_deceased'
 when qualifying_condition_fill_count>0 then 'qualifying_dispensing_observed'
 when source_latest_fill_date is null then 'unable_to_assess_pharmacy_feed'
 when possible_condition_fill_count>0 then 'unable_to_assess_possible_class'
 when annual_unknown_medication_flag=1 then 'unable_to_assess_unmapped_or_undated_medication'
 else 'potential_open_drug_gap' end as gap_status,
 {{ dbt.datediff('estimated_refill_due_date','assessment_date','day') }} as days_overdue
 from facts
), assessed as (
 select *,case when refill_condition_eligible_flag=0 then 'not_in_scope'
 when deceased_flag=1 then 'excluded_deceased'
 when source_latest_fill_date is null then 'unable_to_assess_pharmacy_feed'
 when unknown_duration_flag=1 then 'unable_to_assess_days_supply'
 when annual_unknown_medication_flag=1 then 'unable_to_assess_unmapped_or_undated_medication'
 when maintenance_fill_dates<{{ var('drugs_refill_min_fills') }} then 'no_repeat_maintenance_history'
 when days_overdue between -{{ var('drugs_refill_lookahead_days') }} and {{ var('drugs_refill_max_overdue_days') }}
   and (active_maintenance_supply_flag=0 or days_overdue<0)
 then case when days_overdue>0 then 'overdue' when days_overdue=0 then 'due_today' else 'due_soon' end
 else 'not_due' end as refill_status
 from gap_assessed
)
select {{ the_tuva_project.stable_id_hash(["'drugs_condition_status'",'person_id','data_source','condition_code']) }} as condition_status_id,*,
 '365_day_class_dispensing' as gap_assessment_basis,
 cast(case when gap_status='potential_open_drug_gap' then 1 when gap_status like 'unable_to_assess%' then null else 0 end as {{ dbt.type_int() }}) as open_drug_gap_flag,
 cast(case when refill_status in ('due_soon','due_today','overdue') then 1
 when refill_status='not_in_scope' or refill_status like 'unable_to_assess%' then null else 0 end as {{ dbt.type_int() }}) as needs_refill_flag,
 case when qualifying_condition_fill_count>0 then 'qualifying_dispensing_in_365_days'
 when possible_condition_fill_count>0 then 'possible_dispensing_in_365_days'
 else 'no_qualifying_dispensing_in_365_days' end as gap_history
from assessed
