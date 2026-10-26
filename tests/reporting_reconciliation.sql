select s.data_source,s.condition_code as report_key from {{ ref('drugs__condition_summary') }} s
left join (select data_source,condition_code,count(*) as n from {{ ref('drugs__open_drug_gap') }} group by data_source,condition_code) g using(data_source,condition_code)
left join (select data_source,condition_code,count(*) as n from {{ ref('drugs__needs_refill') }} group by data_source,condition_code) r using(data_source,condition_code)
where s.patients_with_open_gaps<>coalesce(g.n,0) or s.patients_needing_refill<>coalesce(r.n,0)
union all
select data_source,clinical_drug_id from {{ ref('drugs__brand_generic_summary') }}
where patients_who_could_switch<>patients_with_savings_estimate+patients_without_savings_estimate
or (patients_without_savings_estimate>0 and annual_savings_if_all_switched is not null)
or (patients_without_savings_estimate=0 and abs(annual_savings_if_all_switched-annual_savings_for_priced_patients)>0.01)
