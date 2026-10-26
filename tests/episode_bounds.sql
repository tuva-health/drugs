select episode_id from {{ ref('drugs__drug_episode') }} where episode_end_date<episode_start_date or covered_days<=0 or uncovered_days<0 or episode_span_days<>covered_days+uncovered_days
