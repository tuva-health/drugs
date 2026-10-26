select f.data_source from (select data_source,count(*) as n from {{ ref('drugs__fill') }} group by data_source) f
join (select data_source,sum(fill_count) as n from {{ ref('drugs__drug_episode') }} group by data_source) e on f.data_source=e.data_source where f.n<>e.n
