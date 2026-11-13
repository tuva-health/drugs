-- Exact ATC-level matching preserves every membership. Prefer direct classes;
-- use clinical-product classes only when the product has no direct classes.
-- No proprietary ingredient IDs, name parsing or ATC prefix inference.
with classified_products as (
 select distinct drug_id from {{ ref('drugs__stg_classes') }}
 where coalesce(atc_4_code,atc_3_code,atc_2_code,atc_1_code) is not null
), product_classes as (
 select distinct d.drug_id,c.atc_1_code,c.atc_2_code,c.atc_3_code,c.atc_4_code
 from {{ ref('drugs__stg_drugs') }} d
 left join classified_products p on d.drug_id=p.drug_id
 join {{ ref('drugs__stg_classes') }} c on c.drug_id=coalesce(p.drug_id,d.clinical_drug_id)
), matches as (
 select c.drug_id,r.*,c.atc_4_code
 from product_classes c join {{ ref('drugs__condition_rule') }} r
 on r.atc_code=case r.atc_level when 1 then c.atc_1_code when 2 then c.atc_2_code
   when 3 then c.atc_3_code when 4 then c.atc_4_code end
), ranked as (
 select *,row_number() over(partition by drug_id,condition_code
 order by case when evidence_strength='qualifying' then 0 else 1 end,rule_id,atc_4_code) as evidence_rank
 from matches
)
select drug_id,condition_code,condition_name,condition_family,
 max(case when evidence_rank=1 then rule_id end) as evidence_rule_id,
 max(case when evidence_rank=1 then atc_4_code end) as evidence_atc_4_code,
 max(case when gap_eligible_flag=1 and evidence_strength='qualifying' then 1 else 0 end) as qualifying_class_flag,
 max(case when gap_eligible_flag=1 and evidence_strength='possible' then 1 else 0 end) as possible_class_flag,
 case when max(case when gap_eligible_flag=1 and evidence_strength='qualifying' then 1 else 0 end)=1
   then 'qualifying' else 'possible' end as evidence_strength,
 max(refill_eligible_flag) as refill_eligible_flag,max(refill_possible_flag) as refill_possible_flag,
 max(case when refill_eligible_flag=1 and refill_possible_flag=0 then 1 else 0 end) as refill_qualifying_class_flag
from ranked group by drug_id,condition_code,condition_name,condition_family
