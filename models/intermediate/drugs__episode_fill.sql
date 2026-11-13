-- Supply is first computed at the clinical-product grain in drugs__fill.
-- Episodes then combine strengths/brands that share the COMPLETE vendor
-- ingredient identity and dose form. Combination products are never exploded.
with mapped as (
 select medication_id, person_id, data_source,
        therapy_id as clinical_product_key,
        {{ the_tuva_project.stable_id_hash(["'drugs_episode_therapy'", 'ingredient_id', 'dose_form_id']) }} as therapy_id,
        concat(ingredient_name, ' (', dose_form_name, ')') as therapy_name,
        'ingredient_combination_dose_form' as therapy_grain,
        ingredient_id as drug_code, ingredient_name as drug_name,
        ingredient_type, dose_form_id, dose_form_name,
        case when ingredient_type in ('IN', 'MIN') then 'RxNorm'
             else 'CodeRx ingredient group' end as drug_code_system,
        drug_id, clinical_drug_id, rxnorm_code,
        dispensing_date, days_supply, supply_start_date, supply_end_date
 from {{ ref('drugs__fill') }}
 where {{ 1 if drugs_enterprise() else 0 }} = 1
   and nullif(trim(ingredient_id), '') is not null
   and nullif(trim(ingredient_name), '') is not null
   and nullif(trim(dose_form_id), '') is not null
   and nullif(trim(dose_form_name), '') is not null
), previous as (
 select *,max(supply_end_date) over(partition by person_id,data_source,therapy_id
 order by supply_start_date,supply_end_date,medication_id rows between unbounded preceding and 1 preceding) as previous_end
 from mapped
), boundaries as (
 select *,case when previous_end is null or {{ dbt.datediff('previous_end','supply_start_date','day') }} > {{ var('drugs_episode_gap_days') }}+1 then 1 else 0 end as new_episode,
 case when previous_end is null then days_supply
 else greatest(0,{{ dbt.datediff('greatest(supply_start_date, cast('+dbt.dateadd('day',1,'previous_end')+' as date))','supply_end_date','day') }}+1) end as contributed_covered_days
 from previous
)
select *,sum(new_episode) over(partition by person_id,data_source,therapy_id
 order by supply_start_date,supply_end_date,medication_id rows unbounded preceding) as episode_number
from boundaries
