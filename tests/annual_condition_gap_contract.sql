-- Supply uncertainty must never overturn an observed qualifying annual fill.
select condition_status_id from {{ ref('drugs__condition_status') }}
where (qualifying_condition_fill_count>0 and open_drug_gap_flag<>0)
 or (deceased_flag=0 and qualifying_condition_fill_count=0
  and (possible_condition_fill_count>0 or annual_unknown_medication_flag=1 or source_latest_fill_date is null)
  and open_drug_gap_flag is not null)
 or (refill_condition_eligible_flag=0 and (needs_refill_flag is not null or refill_status<>'not_in_scope'))
