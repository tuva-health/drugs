with a as (select data_source,count(*) as n from {{ source('tuva_core','medication') }} where source_type='claims' group by data_source),
b as (select data_source,count(*) as n from {{ ref('drugs__medication') }} group by data_source)
select coalesce(a.data_source,b.data_source) as data_source from a full outer join b on a.data_source=b.data_source where coalesce(a.n,0)<>coalesce(b.n,0)
