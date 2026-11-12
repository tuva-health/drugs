-- Complete combinations must not explode a dispensing into component rows.
select data_source, person_id, medication_id
from {{ ref('drugs__episode_fill') }}
group by data_source, person_id, medication_id
having count(*) > 1
