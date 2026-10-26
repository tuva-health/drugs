{{ config(alias='source_freshness') }}
select data_source,{{ drugs_as_of() }} as assessment_date,max(file_date) as source_rx_file_date,
 max(ingest_datetime) as source_rx_ingest_datetime,max(case when dispensing_date<={{ drugs_as_of() }} then dispensing_date end) as source_latest_fill_date,
 coalesce(max(file_date),cast(max(ingest_datetime) as date)) as source_rx_freshness_date,
 case when max(file_date) is not null then 'file_date' when max(ingest_datetime) is not null then 'ingest_datetime' else 'unavailable' end as source_rx_freshness_basis
from {{ ref('drugs__medication') }} group by data_source
