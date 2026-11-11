-- Compare each claim's payer-paid value, including NULL versus zero.
-- Start from Core medication so a missing pharmacy evidence row is visible.
with expected as (
    select m.data_source, m.person_id, m.medication_id,
           p.pharmacy_claim_id, p.paid_amount
    from {{ ref('core__medication') }} m
    left join {{ ref('core__pharmacy_claim') }} p
        on m.data_source = p.data_source
       and m.person_id = p.person_id
       and m.medication_id = p.pharmacy_claim_id
    where m.source_type = 'claims'
)
select
    coalesce(e.data_source, a.data_source) as data_source,
    coalesce(e.person_id, a.person_id) as person_id,
    coalesce(e.medication_id, a.medication_id) as medication_id
from expected e
full outer join {{ ref('drugs__medication') }} a
    on e.data_source = a.data_source
   and e.person_id = a.person_id
   and e.medication_id = a.medication_id
where e.medication_id is null or a.medication_id is null
   or e.pharmacy_claim_id is null
   or e.paid_amount <> a.paid_amount
   or (e.paid_amount is null and a.paid_amount is not null)
   or (e.paid_amount is not null and a.paid_amount is null)
