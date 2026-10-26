{{ config(alias='patient_context') }}
with population as (
 select person_id,data_source from {{ source('tuva_core','patient') }}
 union select person_id,data_source from {{ ref('drugs__medication') }}
 union select person_id,data_source from {{ ref('drugs__condition_evidence') }}
), demographics as (
 select person_id,data_source,max(case when death_flag=1 or death_date<={{ drugs_as_of() }} then 1 else 0 end) as deceased_flag
 from {{ source('tuva_core','patient') }} group by person_id,data_source
), eligibility as (
 select person_id,data_source,max(case when enrollment_start_date<={{ drugs_as_of() }} and (enrollment_end_date is null or enrollment_end_date>={{ drugs_as_of() }}) then 1 else 0 end) as currently_enrolled_flag,
 max({{ drugs_optional_column(source('tuva_core','eligibility'),'file_date','e','date') }}) as eligibility_file_date,
 max(ingest_datetime) as eligibility_ingest_datetime
 from {{ source('tuva_core','eligibility') }} e group by person_id,data_source
), rx as (
 select person_id,data_source,max(file_date) as patient_rx_file_date,max(ingest_datetime) as patient_rx_ingest_datetime,
 max(case when dispensing_date<={{ drugs_as_of() }} then dispensing_date end) as patient_latest_fill_date,
 max(case when dispensing_date between {{ dbt.dateadd('day',-var('drugs_uncertain_exposure_days')+1,drugs_as_of()) }} and {{ drugs_as_of() }} and drug_id is null then 1 else 0 end) as recent_unmapped_drug_flag
 from {{ ref('drugs__medication') }} group by person_id,data_source
), context as (
 select p.person_id,p.data_source,{{ drugs_as_of() }} as assessment_date,coalesce(d.deceased_flag,0) as deceased_flag,
 coalesce(e.currently_enrolled_flag,0) as currently_enrolled_flag,e.eligibility_file_date,e.eligibility_ingest_datetime,
 r.patient_rx_file_date,r.patient_rx_ingest_datetime,r.patient_latest_fill_date,coalesce(r.recent_unmapped_drug_flag,0) as recent_unmapped_drug_flag,
 coalesce(r.patient_rx_file_date,cast(r.patient_rx_ingest_datetime as date)) as patient_rx_freshness_date,
 case when r.patient_rx_file_date is not null then 'file_date' when r.patient_rx_ingest_datetime is not null then 'ingest_datetime' else 'unavailable' end as patient_rx_freshness_basis,
 s.source_rx_file_date,s.source_rx_ingest_datetime,s.source_latest_fill_date,s.source_rx_freshness_date,s.source_rx_freshness_basis
 from population p left join demographics d using(person_id,data_source) left join eligibility e using(person_id,data_source)
 left join rx r using(person_id,data_source) left join {{ ref('drugs__source_freshness') }} s using(data_source)
)
select *,{{ dbt.datediff('patient_rx_freshness_date','assessment_date','day') }} as patient_rx_age_days,
 {{ dbt.datediff('source_rx_freshness_date','assessment_date','day') }} as source_rx_age_days,
 {{ dbt.datediff('source_latest_fill_date','assessment_date','day') }} as source_clinical_lag_days,
 case when deceased_flag=1 then 'deceased'
 when currently_enrolled_flag=0 then 'confirm_current_enrollment'
 when source_rx_freshness_date is null then 'unknown_source_freshness'
 when source_rx_freshness_date>assessment_date then 'future_source_freshness'
 when {{ dbt.datediff('source_rx_freshness_date','assessment_date','day') }}>{{ var('drugs_freshness_days') }} or {{ dbt.datediff('source_latest_fill_date','assessment_date','day') }}>{{ var('drugs_freshness_days') }} then 'lagged_source_confirm_current_status'
 else 'current_record_review' end as outreach_readiness_status
from context
