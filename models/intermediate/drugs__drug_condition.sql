-- Match all ATC memberships, never just an arbitrarily selected primary class.
-- CodeRx supplies ATC levels 1-4. Ingredient-specific clinical policy uses
-- CodeRx Enterprise's atomic IN relationships; no names are parsed.
-- Prefer a product's direct mapping; use its clinical product only when absent.
with mapped_codes as (
 select distinct drug_id from {{ ref('drugs__stg_ingredient') }}
)
select d.drug_id,r.condition_code,r.condition_name,min(r.rule_id) as evidence_rule_id,
 min(c.atc_4_code) as evidence_atc_4_code,max(r.refill_eligible_flag) as refill_eligible_flag
from {{ ref('drugs__stg_drugs') }} d join {{ ref('drugs__stg_classes') }} c on d.drug_id=c.drug_id
left join mapped_codes m on d.drug_id=m.drug_id
left join {{ ref('drugs__stg_ingredient') }} i on coalesce(m.drug_id,d.clinical_drug_id)=i.drug_id
join {{ ref('drugs__condition_rule') }} r
 on coalesce(c.atc_4_code,c.atc_3_code,c.atc_2_code) like concat(r.atc_prefix,'%')
 and (r.ingredient_rxcui is null or i.ingredient_id=cast(r.ingredient_rxcui as {{ dbt.type_string() }}))
group by d.drug_id,r.condition_code,r.condition_name
