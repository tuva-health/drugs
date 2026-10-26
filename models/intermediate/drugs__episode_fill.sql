with previous as (
 select *,max(supply_end_date) over(partition by person_id,data_source,therapy_id
 order by supply_start_date,supply_end_date,medication_id rows between unbounded preceding and 1 preceding) as previous_end
 from {{ ref('drugs__ingredient_fill') }}
), boundaries as (
 select *,case when previous_end is null or {{ dbt.datediff('previous_end','supply_start_date','day') }} > {{ var('drugs_episode_gap_days') }}+1 then 1 else 0 end as new_episode,
 case when previous_end is null then days_supply
 else greatest(0,{{ dbt.datediff('greatest(supply_start_date, cast('+dbt.dateadd('day',1,'previous_end')+' as date))','supply_end_date','day') }}+1) end as contributed_covered_days
 from previous
)
select *,sum(new_episode) over(partition by person_id,data_source,therapy_id
 order by supply_start_date,supply_end_date,medication_id rows unbounded preceding) as episode_number
from boundaries
