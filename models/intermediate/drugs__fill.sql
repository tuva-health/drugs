-- The default follows OHDSI's non-stockpiling convention. Optional carryover
-- is isolated to the same clinical ingredient/strength/form and source/person.
{% set stockpile = var('drugs_stockpile_early_refills', false) %}
{% if stockpile is not boolean %}{{ exceptions.raise_compiler_error('drugs_stockpile_early_refills must be a YAML boolean') }}{% endif %}
with usable as (
 select * from {{ ref('drugs__medication') }} where exposure_status='usable'
), supply as (
 select *,coalesce(sum(days_supply) over(partition by person_id,data_source,therapy_id
 order by dispensing_date,medication_id rows between unbounded preceding and 1 preceding),0) as prior_supply
 from usable
), anchors as (
 select *,{{ dbt.dateadd('day','-prior_supply','dispensing_date') }} as supply_anchor from supply
), adjusted as (
 select *,cast({% if stockpile %}{{ dbt.dateadd('day','prior_supply','max(supply_anchor) over(partition by person_id,data_source,therapy_id order by dispensing_date,medication_id rows unbounded preceding)') }}{% else %}dispensing_date{% endif %} as date) as supply_start_date from anchors
)
select medication_id,person_id,data_source,therapy_id,therapy_name,therapy_grain,drug_id,clinical_drug_id,
 dispensing_date,days_supply,supply_start_date,
 cast({{ dbt.dateadd('day','days_supply-1','supply_start_date') }} as date) as supply_end_date
from adjusted
