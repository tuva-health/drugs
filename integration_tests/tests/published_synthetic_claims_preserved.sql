{{ config(tags=['drugs_scenarios']) }}
-- The extra scenarios must not replace or filter the released synthetic claims.
select 'pharmacy_claim' as relation_name
where (select count(*) from {{ ref('core__pharmacy_claim') }}
       where data_source not in (select distinct data_source from {{ ref('scenario_people') }}))
 <> (select count(*) from {{ ref('the_tuva_project','synthetic_data__pharmacy_claim') }})
union all
select 'medical_claim'
where (select count(*) from {{ ref('core__medical_claim') }}
       where data_source not in (select distinct data_source from {{ ref('scenario_people') }}))
 <> (select count(*) from {{ ref('the_tuva_project','synthetic_data__medical_claim') }})
