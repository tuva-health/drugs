-- Expand combination products into atomic ingredients AFTER computing supply
-- at the clinical-product level. Never transfer stockpiled supply across doses.
with mapped_codes as (select distinct drug_id from {{ ref('drugs__stg_ingredient') }})
select f.medication_id,f.person_id,f.data_source,f.therapy_id as clinical_product_key,
 i.ingredient_id as drug_code,i.ingredient_name as drug_name,i.mapping_source as ingredient_mapping_source,
 concat('ingredient:',i.ingredient_id) as therapy_id,i.ingredient_name as therapy_name,'ingredient' as therapy_grain,
 f.drug_id,f.clinical_drug_id,f.rxnorm_code,f.dispensing_date,f.days_supply,f.supply_start_date,f.supply_end_date
from {{ ref('drugs__fill') }} f
left join mapped_codes m on f.drug_id=m.drug_id
left join mapped_codes c on f.clinical_drug_id=c.drug_id
left join mapped_codes r on f.rxnorm_code=r.drug_id
join {{ ref('drugs__stg_ingredient') }} i on coalesce(m.drug_id,c.drug_id,r.drug_id)=i.drug_id
