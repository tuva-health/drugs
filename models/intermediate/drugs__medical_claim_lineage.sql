select person_id,data_source,claim_id,max(ingest_datetime) as ingest_datetime,
 max({{ drugs_optional_column(ref('core__medical_claim'),'file_date','c','date') }}) as file_date
from {{ ref('core__medical_claim') }} c group by person_id,data_source,claim_id
