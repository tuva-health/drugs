{{ config(tags=['drugs_scenarios']) }}
-- Every fabricated dispensing must pass through Core exactly once. Missing
-- days supply stays unknown, and payer paid stays attached to the same claim.
select s.data_source,s.claim_id
from {{ ref('scenario_pharmacy_claims') }} s
join {{ ref('scenario_products') }} p on s.drug_key=p.drug_key
left join {{ ref('core__medication') }} m
 on s.person_id=m.person_id and s.data_source=m.data_source and s.claim_id=m.claim_id
 and m.claim_line_number=1
left join {{ ref('core__pharmacy_claim') }} c
 on m.medication_id=c.pharmacy_claim_id and m.person_id=c.person_id and m.data_source=c.data_source
group by s.data_source,s.claim_id,p.ndc_code,p.drug_id,s.days_supply,s.quantity,s.paid_amount
having count(m.medication_id)<>1
 or coalesce(min(m.source_type),'missing')<>'claims'
 or coalesce(min(m.ndc_code),'missing')<>p.ndc_code
 or coalesce(min(m.rxnorm_code),'missing')<>p.drug_id
 or coalesce(min(m.days_supply),-1)<>coalesce(s.days_supply,-1)
 or coalesce(min(m.quantity),-1)<>s.quantity
 or count(c.pharmacy_claim_id)<>1
 or abs(coalesce(min(c.paid_amount),-1)-s.paid_amount)>0.00001
