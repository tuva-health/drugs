{{ config(alias='medication_condition') }}
select m.medication_id,m.person_id,m.data_source,m.therapy_id,m.drug_id,m.drug_name,m.clinical_drug_id,
 m.dispensing_date,m.days_supply,m.exposure_status,m.file_date,m.ingest_datetime,
 r.condition_code,r.condition_name,r.evidence_rule_id,r.evidence_atc_4_code,r.refill_eligible_flag,
 f.supply_start_date,f.supply_end_date,
 case when {{ drugs_as_of() }} between f.supply_start_date and f.supply_end_date then 1 else 0 end as active_supply_flag
from {{ ref('drugs__medication') }} m join {{ ref('drugs__drug_condition') }} r on m.drug_id=r.drug_id
left join {{ ref('drugs__fill') }} f on m.person_id=f.person_id and m.data_source=f.data_source and m.medication_id=f.medication_id
where m.dispensing_date<={{ drugs_as_of() }}
