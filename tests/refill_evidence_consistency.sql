-- The displayed maintenance drug must be the fill that supplies the due date.
select s.person_id,s.data_source,s.condition_code
from {{ ref('drugs__condition_medication_summary') }} s
left join {{ ref('drugs__medication_condition') }} m
 on s.person_id=m.person_id and s.data_source=m.data_source
 and s.condition_code=m.condition_code and s.latest_maintenance_medication_id=m.medication_id
where (s.maintenance_supply_end_date is null and s.latest_maintenance_medication_id is not null)
 or (s.maintenance_supply_end_date is not null and (
  m.medication_id is null or m.refill_eligible_flag<>1 or m.exposure_status<>'usable'
  or m.supply_end_date is null or s.maintenance_supply_end_date<>m.supply_end_date
  or s.latest_maintenance_drug_name<>m.drug_name
  or (s.latest_maintenance_drug_name is null and m.drug_name is not null)
  or (s.latest_maintenance_drug_name is not null and m.drug_name is null)
 ))
