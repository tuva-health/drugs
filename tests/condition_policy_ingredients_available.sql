-- A typo or an unsupported ingredient in the clinical policy must not silently
-- turn a known treatment into a gap. IDs are resolved only by CodeRx Enterprise.
select r.rule_id
from {{ ref('drugs__condition_rule') }} r
left join (
 select distinct ingredient_id from {{ ref('drugs__stg_ingredient') }}
) i on cast(r.ingredient_rxcui as {{ dbt.type_string() }})=i.ingredient_id
where {{ 1 if drugs_enterprise() else 0 }}=1
 and r.ingredient_rxcui is not null and i.ingredient_id is null
