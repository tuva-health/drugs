-- A missing entire source must fail as well as a mismatched count.
with mapped as (
 select data_source,count(*) as fill_count from {{ ref('drugs__episode_fill') }} group by data_source
), episodes as (
 select data_source,sum(fill_count) as fill_count from {{ ref('drugs__drug_episode') }} group by data_source
)
select coalesce(m.data_source,e.data_source) as data_source
from mapped m full outer join episodes e on m.data_source=e.data_source
where coalesce(m.fill_count,0)<>coalesce(e.fill_count,0)
