-- CodeRx Enterprise is the sole authority for atomic ingredient relationships.
{% if drugs_enterprise() %}
{% do drugs_validate_enterprise_relation('ingredients') %}
select
    cast(drug_id as {{ dbt.type_string() }}) as drug_id,
    cast(ingredient_component_id as {{ dbt.type_string() }}) as ingredient_id,
    min(ingredient_component_name) as ingredient_name,
    'coderx_enterprise' as mapping_source
from {{ source('coderx_enterprise', 'ingredients') }}
where ingredient_component_type = 'IN'
  and ingredient_component_id is not null
  and drug_id is not null
group by drug_id, ingredient_component_id
{% else %}
-- A stable empty schema lets Open notebooks run without implying ingredient coverage.
select
    cast(null as {{ dbt.type_string() }}) as drug_id,
    cast(null as {{ dbt.type_string() }}) as ingredient_id,
    cast(null as {{ dbt.type_string() }}) as ingredient_name,
    cast(null as {{ dbt.type_string() }}) as mapping_source
where 1 = 0
{% endif %}
