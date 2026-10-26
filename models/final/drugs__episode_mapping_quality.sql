{{ config(alias='episode_mapping_quality') }}
with mapped as (select distinct medication_id,person_id,data_source from {{ ref('drugs__ingredient_fill') }})
select m.data_source,count(*) as medication_claim_count,
 sum(case when m.exposure_status='usable' then 1 else 0 end) as usable_supply_claim_count,
 sum(case when f.medication_id is not null then 1 else 0 end) as ingredient_mapped_claim_count,
 sum(case when m.exposure_status='usable' and f.medication_id is null then 1 else 0 end) as usable_claims_without_ingredient,
 sum(case when m.exposure_status<>'usable' then 1 else 0 end) as unusable_supply_claim_count
from {{ ref('drugs__medication') }} m left join mapped f on m.medication_id=f.medication_id and m.person_id=f.person_id and m.data_source=f.data_source
group by m.data_source
