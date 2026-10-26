select m.data_source from {{ ref('drugs__medication') }} m
join {{ source('tuva_core','pharmacy_claim') }} c on m.data_source=c.data_source and m.person_id=c.person_id and m.medication_id=c.pharmacy_claim_id
group by m.data_source having abs(coalesce(sum(m.paid_amount),0)-coalesce(sum(c.paid_amount),0))>0.01
