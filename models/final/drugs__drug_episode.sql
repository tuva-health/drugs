{{ config(alias='drug_episode') }}
with episodes as (
 select person_id,data_source,therapy_id,min(therapy_name) as therapy_name,min(therapy_grain) as therapy_grain,
 episode_number,min(supply_start_date) as episode_start_date,max(supply_end_date) as episode_end_date,
 count(*) as fill_count,count(distinct dispensing_date) as distinct_fill_dates,sum(contributed_covered_days) as covered_days,
 max(case when {{ drugs_as_of() }} between supply_start_date and supply_end_date then 1 else 0 end) as active_supply_flag
 from {{ ref('drugs__episode_fill') }} group by person_id,data_source,therapy_id,episode_number
)
select {{ dbt_utils.generate_surrogate_key(['person_id','data_source','therapy_id','episode_start_date']) }} as episode_id,
 e.*,{{ drugs_as_of() }} as assessment_date,{{ var('drugs_episode_gap_days') }} as permissible_gap_days,
 {{ dbt.datediff('episode_start_date','episode_end_date','day') }}+1 as episode_span_days,
 {{ dbt.datediff('episode_start_date','episode_end_date','day') }}+1-covered_days as uncovered_days,
 case when episode_number>1 then 1 else 0 end as restart_flag,
 case when episode_end_date>={{ drugs_as_of() }} then 'supply_extends_to_assessment'
 when {{ dbt.dateadd('day',var('drugs_episode_gap_days'),'episode_end_date') }}>={{ drugs_as_of() }} then 'within_permissible_gap'
 else 'no_later_supply_observed' end as episode_end_status
from episodes e
