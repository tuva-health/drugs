select b.person_id,b.data_source,b.clinical_drug_id,count(*) as benchmark_claim_count,
 count(distinct g.person_id) as benchmark_person_count,
 percentile_cont(0.5) within group(order by g.paid_amount/g.quantity) as generic_paid_per_unit,
 min(g.dispensing_date) as benchmark_first_fill_date,max(g.dispensing_date) as benchmark_last_fill_date,
 max(g.file_date) as benchmark_file_date,max(g.ingest_datetime) as benchmark_ingest_datetime
from {{ ref('drugs__current_brand') }} b join {{ ref('drugs__medication') }} g
 on b.data_source=g.data_source and b.clinical_drug_id=g.clinical_drug_id
 and (b.payer=g.payer or (b.payer is null and g.payer is null)) and (b.plan=g.plan or (b.plan is null and g.plan is null))
 and g.dispensing_date between {{ dbt.dateadd('day',-var('drugs_generic_lookback_days')+1,drugs_as_of()) }} and {{ drugs_as_of() }}
 and abs(b.quantity/nullif(b.days_supply,0)-g.quantity/nullif(g.days_supply,0))<0.01
join {{ ref('drugs__generic_alternative') }} a on g.ndc_code=a.generic_ndc_code and g.clinical_drug_id=a.clinical_drug_id
where g.brand_flag=0 and g.exposure_status='usable' and g.quantity>0 and g.paid_amount>0
 and b.quantity>0 and b.paid_amount>0
group by b.person_id,b.data_source,b.clinical_drug_id
