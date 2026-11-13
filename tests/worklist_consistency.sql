select condition_status_id from {{ ref('drugs__open_drug_gap') }}
where open_drug_gap_flag<>1 or qualifying_condition_fill_count<>0 or possible_condition_fill_count<>0
 or annual_unknown_medication_flag<>0 or source_latest_fill_date is null or deceased_flag<>0
union all
select condition_status_id from {{ ref('drugs__needs_refill') }}
where needs_refill_flag<>1 or refill_condition_eligible_flag<>1
 or maintenance_fill_dates<{{ var('drugs_refill_min_fills') }}
 or latest_maintenance_medication_id is null or latest_maintenance_therapy_id is null
 or unknown_duration_flag<>0 or annual_unknown_medication_flag<>0
 or refill_class_confidence not in ('qualifying','possible')
 or days_overdue not between -{{ var('drugs_refill_lookahead_days') }} and {{ var('drugs_refill_max_overdue_days') }}
