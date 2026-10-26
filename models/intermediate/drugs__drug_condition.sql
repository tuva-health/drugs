-- Match all ATC memberships, never just an arbitrarily selected primary class.
select d.drug_id,r.condition_code,r.condition_name,min(r.rule_id) as evidence_rule_id,
 min(c.atc_4_code) as evidence_atc_4_code,max(r.refill_eligible_flag) as refill_eligible_flag
from {{ ref('drugs__stg_drugs') }} d join {{ ref('drugs__stg_classes') }} c on d.drug_id=c.drug_id
join {{ ref('drugs__condition_rule') }} r
 on coalesce(c.atc_4_code,c.atc_3_code,c.atc_2_code) like concat(r.atc_prefix,'%')
 and (r.drug_name_contains is null or lower(coalesce(d.clinical_drug_name,d.drug_name)) like concat('%',lower(r.drug_name_contains),'%'))
group by d.drug_id,r.condition_code,r.condition_name
