-- Every code is matched at its exact declared level, never by prefix.
select rule_id from {{ ref('drugs__condition_rule') }}
where atc_code is null or atc_level is null
 or {{ dbt.length('atc_code') }}<>case atc_level when 1 then 1 when 2 then 3 when 3 then 4 when 4 then 5 else -1 end
 or evidence_strength not in ('qualifying','possible') or evidence_strength is null
 or gap_eligible_flag<>1 or refill_eligible_flag not in (0,1) or refill_possible_flag not in (0,1)
 or (refill_eligible_flag=1 and condition_code not in ('t2d','htn','cad','copd','asthma','chf','afib'))
