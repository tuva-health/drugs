with current_products as (
 select m.*,f.supply_end_date,
 row_number() over(partition by m.person_id,m.data_source,m.clinical_drug_id order by m.dispensing_date desc,m.medication_id desc) as current_rank
 from {{ ref('drugs__medication') }} m join {{ ref('drugs__fill') }} f on m.person_id=f.person_id and m.data_source=f.data_source and m.medication_id=f.medication_id
 where {{ drugs_as_of() }} between f.supply_start_date and f.supply_end_date
 and m.clinical_drug_id is not null
)
select *,case when coalesce(marketing_screening_applied_flag,0)=1
              then 'enterprise_nda_category' else 'brand_flag' end as brand_screening_basis
from current_products b where current_rank=1 and brand_flag=1
and (coalesce(marketing_screening_applied_flag,0)=0 or upper(marketing_category) like 'NDA%')
-- An overlapping newer generic or unknown-duration fill may represent a switch.
-- Do not count an earlier brand as a current saving opportunity in that case.
and not exists(select 1 from {{ ref('drugs__medication') }} n where n.person_id=b.person_id and n.data_source=b.data_source
 and n.clinical_drug_id=b.clinical_drug_id and n.dispensing_date between b.dispensing_date and {{ drugs_as_of() }}
 and (n.brand_flag=0 or n.exposure_status<>'usable'))
