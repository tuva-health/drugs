with therapy_history as (
 select person_id,data_source,condition_code,therapy_id,
 count(distinct case when refill_eligible_flag=1 and exposure_status='usable' and therapy_id is not null
   then dispensing_date end) as therapy_maintenance_fill_dates
 from {{ ref('drugs__medication_condition') }}
 group by person_id,data_source,condition_code,therapy_id
), ranked as (
 select m.*,h.therapy_maintenance_fill_dates,
 row_number() over(partition by m.person_id,m.data_source,m.condition_code
 order by case when m.refill_eligible_flag=1 and m.exposure_status='usable'
   and m.supply_end_date is not null
   and h.therapy_maintenance_fill_dates>={{ var('drugs_refill_min_fills') }} then 0 else 1 end,
 m.supply_end_date desc,m.dispensing_date desc,m.medication_id desc) as latest_rank
 from {{ ref('drugs__medication_condition') }} m
 join therapy_history h on m.person_id=h.person_id and m.data_source=h.data_source
   and m.condition_code=h.condition_code
   and (m.therapy_id=h.therapy_id or (m.therapy_id is null and h.therapy_id is null))
), marked as (
 select *,case when latest_rank=1 and refill_eligible_flag=1 and exposure_status='usable'
   and supply_end_date is not null
   and therapy_maintenance_fill_dates>={{ var('drugs_refill_min_fills') }} then 1 else 0 end as selected_refill_fill_flag
 from ranked
)
select person_id,data_source,condition_code,count(*) as prior_condition_fill_count,
 sum(case when qualifying_class_flag=1 then 1 else 0 end) as qualifying_condition_fill_count,
 sum(case when qualifying_class_flag=0 and possible_class_flag=1 then 1 else 0 end) as possible_condition_fill_count,
 max(active_supply_flag) as active_condition_supply_flag,
 max(case when refill_eligible_flag=1 and exposure_status='usable' then active_supply_flag else 0 end) as active_maintenance_supply_flag,
 max(case when refill_eligible_flag=1 and exposure_status<>'usable'
   and dispensing_date>={{ dbt.dateadd('day',-364,drugs_as_of()) }} then 1 else 0 end) as unknown_duration_flag,
 max(refill_possible_flag) as possible_refill_mapping_flag,
 -- Repeated dates and displayed due-date evidence belong to the same therapy/fill.
 max(case when selected_refill_fill_flag=1 then supply_end_date end) as maintenance_supply_end_date,
 max(case when selected_refill_fill_flag=1 then therapy_maintenance_fill_dates else 0 end) as maintenance_fill_dates,
 max(case when selected_refill_fill_flag=1 then medication_id end) as latest_maintenance_medication_id,
 max(case when selected_refill_fill_flag=1 then drug_name end) as latest_maintenance_drug_name,
 max(case when selected_refill_fill_flag=1 then therapy_id end) as latest_maintenance_therapy_id,
 max(case when selected_refill_fill_flag=1 then dispensing_date end) as latest_maintenance_dispensing_date,
 max(case when selected_refill_fill_flag=1 then case when refill_qualifying_class_flag=1 then 'qualifying' else 'possible' end end) as refill_class_confidence,
 max(file_date) as treatment_evidence_file_date,max(ingest_datetime) as treatment_evidence_ingest_datetime
from marked group by person_id,data_source,condition_code
