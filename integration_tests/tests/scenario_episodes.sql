{{ config(tags=['drugs_scenarios']) }}
-- With no stockpiling, Jan 1/Jan 20 overlap covers 49 unique days.
-- Thirty uncovered days keep Mar 21 in that episode; 31 split May 21 out.
with actual as (
 select * from {{ ref('drugs__drug_episode') }} where person_id='sc_episode_boundary'
)
select e.person_id,e.data_source,e.episode_number
from {{ ref('expected_episodes') }} e
left join actual a on e.person_id=a.person_id and e.data_source=a.data_source
 and e.drug_code=a.drug_code and e.episode_number=a.episode_number
where a.episode_id is null or a.start_date<>e.start_date or a.end_date<>e.end_date
 or a.fill_count<>e.fill_count or a.covered_days<>e.covered_days or a.uncovered_days<>e.uncovered_days
union all
select a.person_id,a.data_source,a.episode_number
from actual a left join {{ ref('expected_episodes') }} e
 on e.person_id=a.person_id and e.data_source=a.data_source
 and e.drug_code=a.drug_code and e.episode_number=a.episode_number
where e.person_id is null
