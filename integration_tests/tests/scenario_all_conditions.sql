{{ config(tags=['drugs_scenarios']) }}
-- Every approved condition enters through a real, active billable ICD-10-CM
-- medical claim and Tuva Core's condition grouper. These patients have no Rx.
-- A different patient with one metformin claim establishes the same-source feed.
with expected as (
    select condition_code, condition_name,
        concat('sc_coverage_', condition_code) as person_id,
        case when condition_name in (
            'Type 2 Diabetes Mellitus', 'Hypertension', 'Coronary Artery Disease',
            'Chronic Obstructive Pulmonary Disease', 'Asthma', 'Heart Failure',
            'Atrial Fibrillation and Flutter'
        ) then 1 else 0 end as expected_refill_scope
    from {{ ref('drugs__condition_rule') }}
    where gap_eligible_flag = 1
    group by condition_code, condition_name
), core_conditions as (
    select person_id, condition_name, count(*) as evidence_count
    from {{ ref('core__condition') }}
    where data_source = 'scenario_coverage'
    group by person_id, condition_name
), actual as (
    select * from {{ ref('drugs__condition_status') }}
    where data_source = 'scenario_coverage'
), summary as (
    select * from {{ ref('drugs__condition_summary') }}
    where data_source = 'scenario_coverage'
), failures as (
    select 'core_condition_missing' as failure, e.condition_code
    from expected e left join core_conditions c
        on e.person_id = c.person_id and e.condition_name = c.condition_name
    where c.evidence_count is null

    union all
    select 'condition_status_mismatch', e.condition_code
    from expected e left join actual a
        on e.person_id = a.person_id and e.condition_code = a.condition_code
    where a.condition_status_id is null
       or a.condition_name <> e.condition_name
       or coalesce(a.open_drug_gap_flag, -1) <> 1
       or coalesce(a.qualifying_condition_fill_count, -1) <> 0
       or coalesce(a.possible_condition_fill_count, -1) <> 0
       or coalesce(a.refill_condition_eligible_flag, -1) <> e.expected_refill_scope
       or (e.expected_refill_scope = 1 and coalesce(a.needs_refill_flag, -1) <> 0)
       or (e.expected_refill_scope = 0 and a.needs_refill_flag is not null)

    union all
    select 'condition_summary_mismatch', e.condition_code
    from expected e left join summary s on e.condition_code = s.condition_code
    where s.condition_code is null
       or s.assessed_patients <> 1
       or s.patients_with_open_gaps <> 1
       or s.patients_needing_refill <> 0
       or s.gap_unassessable_patients <> 0
       or s.refill_unassessable_patients <> 0
       or s.refill_denominator_patients <> e.expected_refill_scope
       or (e.expected_refill_scope = 1 and coalesce(s.percent_needing_refill, -1) <> 0)
       or (e.expected_refill_scope = 0 and s.percent_needing_refill is not null)

    union all
    select 'unexpected_condition_status', a.condition_code
    from actual a left join expected e
        on a.person_id = e.person_id and a.condition_code = e.condition_code
    where e.person_id is null

    union all
    select 'approved_condition_count', 'all'
    where (select count(*) from expected) <> 68
       or (select count(*) from actual) <> 68
       or (select count(*) from summary) <> 68
       or (select sum(refill_denominator_patients) from summary) <> 7

    union all
    select 'coverage_worklist_counts', 'all'
    where (select count(*) from {{ ref('drugs__open_drug_gap') }}
           where data_source = 'scenario_coverage') <> 68
       or (select count(*) from {{ ref('drugs__needs_refill') }}
           where data_source = 'scenario_coverage') <> 0

    union all
    select 'medication_feed_control', 'all'
    where (select count(*) from {{ ref('core__medication') }}
           where data_source = 'scenario_coverage' and source_type = 'claims') <> 1
       or (select count(*) from {{ ref('core__medication') }}
           where data_source = 'scenario_coverage' and source_type = 'claims'
             and person_id = 'sc_coverage_rx_control'
             and dispensing_date = cast('2026-11-01' as date)) <> 1
       or (select count(*) from core_conditions
           where person_id = 'sc_coverage_rx_control') <> 0
)
select * from failures
