-- Exact identity reconciliation catches offsetting missing/extra rows and fanout.
with expected as (
    select data_source, person_id, medication_id, count(*) as expected_rows
    from {{ ref('core__medication') }}
    where source_type = 'claims'
    group by data_source, person_id, medication_id
), actual as (
    select data_source, person_id, medication_id, count(*) as actual_rows,
           sum(case when source_type = 'claims' then 0 else 1 end) as non_claim_rows
    from {{ ref('drugs__medication') }}
    group by data_source, person_id, medication_id
)
select
    coalesce(e.data_source, a.data_source) as data_source,
    coalesce(e.person_id, a.person_id) as person_id,
    coalesce(e.medication_id, a.medication_id) as medication_id,
    e.expected_rows,
    a.actual_rows
from expected e
full outer join actual a
    on e.data_source = a.data_source
   and e.person_id = a.person_id
   and e.medication_id = a.medication_id
where e.expected_rows is null or a.actual_rows is null
   or e.expected_rows <> 1 or a.actual_rows <> 1
   or a.non_claim_rows <> 0
