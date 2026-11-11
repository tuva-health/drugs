{{ config(alias='needs_refill') }}
select *,case when days_overdue>0 then 'overdue' when days_overdue=0 then 'due_today' else 'due_soon' end as refill_status,
 'potential_refill; confirm ongoing prescription and scheduled use' as recommendation_basis
from {{ ref('drugs__condition_status') }} where needs_refill_flag=1
 and {{ 1 if drugs_enterprise() else 0 }}=1
