-- Canonical current RxNorm IN relationships are public in both modes.
-- Enterprise extends coverage to historical concepts absent from the current subset.
with public_map as (
 select cast(drug_id as {{ dbt.type_string() }}) as drug_id,
 cast(ingredient_id as {{ dbt.type_string() }}) as ingredient_id,min(ingredient_name) as ingredient_name
 from {{ source('rxnorm_open','drug_ingredient') }}
 where ingredient_id is not null group by drug_id,ingredient_id
)
select drug_id,ingredient_id,ingredient_name,'rxnorm_prescribable' as mapping_source from public_map
{% if drugs_enterprise() %}
union all
select cast(i.drug_id as {{ dbt.type_string() }}) as drug_id,
 cast(i.ingredient_component_id as {{ dbt.type_string() }}) as ingredient_id,
 min(i.ingredient_component_name) as ingredient_name,'coderx_enterprise' as mapping_source
from {{ source('coderx_enterprise','ingredients') }} i
where i.ingredient_component_type='IN' and i.ingredient_component_id is not null
 and not exists(select 1 from public_map p where cast(i.drug_id as {{ dbt.type_string() }})=p.drug_id)
group by i.drug_id,i.ingredient_component_id
{% endif %}
