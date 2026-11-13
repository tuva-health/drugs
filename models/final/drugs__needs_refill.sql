{{ config(alias='needs_refill') }}
select *,
 'potential_refill; confirm ongoing prescription and scheduled versus as-needed use' as recommendation_basis
from {{ ref('drugs__condition_status') }} where needs_refill_flag=1
