{{ config(alias='condition_evidence') }}
select c.condition_id,c.person_id,c.data_source,c.claim_id,c.condition_name,c.condition_family,
 coalesce(c.recorded_date,c.onset_date) as condition_date,c.resolved_date,
 c.code_system,coalesce(c.normalized_code,c.source_code) as diagnosis_code,
 coalesce(c.ingest_datetime,l.ingest_datetime) as ingest_datetime,l.file_date,
 case when c.ingest_datetime is not null then 'core.condition' when l.file_date is not null or l.ingest_datetime is not null then 'core.medical_claim_via_person_source_claim' else 'unavailable' end as freshness_lineage
from {{ source('tuva_core','condition') }} c
left join {{ ref('drugs__medical_claim_lineage') }} l on c.person_id=l.person_id and c.data_source=l.data_source and c.claim_id=l.claim_id
where c.condition_name in (select distinct condition_name from {{ ref('drugs__condition_rule') }})
 and coalesce(c.recorded_date,c.onset_date) between {{ dbt.dateadd('day',-var('drugs_condition_lookback_days')+1,drugs_as_of()) }} and {{ drugs_as_of() }}
 and (c.resolved_date is null or c.resolved_date>{{ drugs_as_of() }})
