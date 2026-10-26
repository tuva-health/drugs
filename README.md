# Drugs

Four medication analytics workflows on top of Tuva Core: **Drug Episodes, Open Drug Gaps, Needs Refill, and Brand vs. Generic**. This standalone dbt package replaces the pharmacy mart removed from Tuva Core after v0.18.0. It does not modify Core or ship licensed terminology or patient data.

## Install and run

Use Tuva Core 1.0 with populated claims data, Tuva condition-grouper names in `core.condition`, and CodeRx terminology. Install this package alongside Core or run it against an existing Core database.

```yaml
# packages.yml in a downstream dbt project
packages:
  - git: https://github.com/tuva-health/drugs.git
    revision: v0.1.0
```

```yaml
# dbt_project.yml in the downstream project
vars:
  drugs_core_database: YOUR_CATALOG
  drugs_core_schema: core
  drugs_terminology_schema: terminology
  use_coderx_enterprise: false
models:
  drugs:
    +schema: drugs
seeds:
  drugs:
    +schema: drugs
```

The standard dbt schema macro appends `drugs` to the target schema when installed as a package. Configure your project's schema macro if you require exactly `drugs`. In a standalone checkout, set the profile's target schema to `drugs`; no schema macro override is needed.

```sh
dbt deps
dbt build --select package:drugs
```

For a standalone Databricks run, install `requirements-databricks.txt` and copy `profiles.yml.example` into your external dbt profiles directory, or use `scripts/run_databricks.py --help` with an existing CLI OAuth login. Keep tokens in environment variables. The package has been executed on Databricks; other adapters require their own validation before deployment.

## Inputs and outputs

`core.medication` is the root medication fact, restricted to `source_type = 'claims'`. `core.pharmacy_claim` supplies payer/plan, **payer-paid amount only**, refill metadata, and file/ingestion provenance, joined on medication ID, person and source. Core must already normalize paid/reversed/denied claims. No authorization count creates additional supply.

Other dependencies are `core.condition`, `core.medical_claim` (diagnosis freshness lineage), `core.patient` (death status), and `core.eligibility` (current membership context). Every patient and claim join is source-scoped. Patients with unconfirmed current enrollment remain visible with a review status; deceased patients are excluded from worklists and opportunities.

| Table | Grain / purpose |
| --- | --- |
| `drug_episode` | Source, patient, clinical drug, observed episode start |
| `open_drug_gap` | Source, patient, condition; potential absence of current qualifying supply |
| `needs_refill` | Source, patient, condition; potential refill due soon or recently overdue |
| `brand_generic_opportunity` | Source, patient, current branded clinical product; availability and prospective savings |
| `medication` | Source and Core medication ID; all claim rows including unusable exposure |
| `condition_status` | All assessed source/patient/condition combinations, including unknown and not-flagged results |
| `condition_evidence` | Relevant Core condition records and freshness lineage |
| `medication_condition` | Medication/condition evidence with matched ATC rule |
| `generic_alternative` | Currently active generic NDC and clinical drug; available independently of observed claims/prices |
| `patient_context`, `source_freshness` | Enrollment, death and patient/source data freshness |

Join `condition_status_id` between the condition worklists. Drill into diagnosis evidence by source/person/condition name and medication evidence by source/person/condition code. `latest_maintenance_medication_id` links directly to `medication`. Join `brand_generic_opportunity.clinical_drug_id` to `generic_alternative` to see candidate NDCs; aggregate savings from the parent opportunity table **before** expanding alternatives to avoid multiplying savings.

## Drug Episodes

The algorithm is inspired by [OHDSI drug eras](https://ohdsi.github.io/CommonDataModel/cdm54.html#drug_era) and [Dima and Dediu's published AdhereR methods](https://doi.org/10.1371/journal.pone.0174426). OHDSI uses a 30-day persistence window; AdhereR explicitly parameterizes permissible gaps and carryover. Our defaults are configurable assumptions, not clinical thresholds.

1. Require a nonfuture dispensing date, an NDC, positive integer days supply of at most 365, and no nonpositive quantity. Missing quantity does not invalidate known days supply. Unknown durations stay in `medication` but do not create exposure.
2. Group at the CodeRx clinical-drug level (ingredient, strength and form). Brand and generic forms of that same clinical drug can share an episode. Different strengths/forms and combination ingredient sets remain separate. Unmapped drugs fall back to NDC; the grain is exposed. This consistent key works in both terminology tiers.
3. A fill's inclusive end is dispensing date + days supply - 1. By default early-fill overlaps are unioned, **without stockpiling**, following OHDSI's convention. Optional stockpiling carries all excess supply within the same clinical product; this is a sensitivity setting and can overestimate supply after dose/regimen changes. No carryover occurs between sources, patients, strengths or forms.
4. Compare each interval with the maximum preceding end. If the uncovered days exceed `drugs_episode_gap_days`, start a new episode. Default 30 means gaps of 0, 1 and 30 days stay in the same episode; 31 starts another. Set 0 for strictly adjacent/overlapping coverage, or 1 to allow one uncovered day.
5. End the episode at the last estimated supply day, with no grace-period extension. Report unioned covered days and actual uncovered days separately. `active_supply_flag` is 1 only when a fill covers the assessment date, regardless of episode tolerance.

Example: a January 1 fill for 30 days ends January 30. January 31 is an adjacent refill with zero uncovered days; February 1 leaves one uncovered day. Both remain one episode under the default. That one uncovered day is still a supply gap.

Episode dates describe observed dispensing history and projected supply, not proven ingestion or original treatment initiation. No eligibility clipping removes supply. `no_later_supply_observed` is not a confirmed discontinuation; consult source freshness. Reported refills are retained as metadata because refill-number semantics vary and authorization is not a dispensing event.

## Open Drug Gaps and Needs Refill

The initial cohorts use unresolved Tuva-grouper condition records in the 365 days ending on the assessment date: Type 2 Diabetes Mellitus, Hypertension, Coronary Artery Disease, Chronic Obstructive Pulmonary Disease, and Asthma. Missing/future condition dates do not qualify. Analysts can edit the versioned `drugs__condition_rule` seed; it is an auditable mapping, not a diagnosis or prescribing protocol.

| Condition | Evidence counted as related medication |
| --- | --- |
| T2D | ATC A10 glucose-lowering drugs, including semaglutide |
| HTN | ATC C02, C03, C07, C08, C09 antihypertensive classes |
| CAD | ATC B01AC antiplatelets, C10 lipid-modifying drugs, C01D cardiac vasodilators, C07 beta blockers |
| COPD / Asthma | ATC R03 obstructive-airway medications; rescue-only drugs count as treatment evidence but do not trigger scheduled refill estimates |

These intentionally broad **any-related-treatment** rules answer the requested question about absent medication evidence. They do not certify guideline-concordant treatment: for example, rescue-only asthma treatment suppresses the broad open-gap flag but does not establish adequate controller treatment, and CAD antiplatelet use does not establish adequate lipid therapy. Many drugs treat several conditions. OTC aspirin, cash fills, samples, administered drugs outside the pharmacy feed and lifestyle-only management can explain an apparent gap.

`open_drug_gap` contains patients with a qualifying condition and **no supply active today**, regardless of whether a drug was ever filled. A recent qualifying claim with unknown duration, or a recent unmapped drug, yields an unable-to-assess status in `condition_status` and a null flag. Known active treatment gives a zero gap flag. A missing pharmacy feed also prevents an assessable gap. Review freshness before outreach.

`needs_refill` requires at least two distinct maintenance dispensing dates in the past 365 days, an estimated due date within the next 7 days or at most 30 days overdue, and no unresolved exposure uncertainty. The due date is the day after the last known maintenance supply ends. A current replacement medication suppresses overdue recommendations. Respiratory rescue-only medications are excluded; repeat controller/long-acting medications can qualify, with scheduled versus PRN use requiring review. The list is condition-level, so it will not flag a missing component of a multidrug regimen while another qualifying treatment covers the condition. Older overdue patients remain in Open Drug Gaps rather than being assumed to need automatic restart.

Due-soon patients need not have an open gap yet; patients due today or recently overdue can appear in both worklists. Flags are independent and evidence is retained.

## Brand vs. Generic

The legacy pharmacy mart's useful distinction between catalog availability and priced opportunities is retained. Current users are identified from estimated supply **on the assessment date**. Select one latest active fill per source/person/clinical drug. A newer overlapping generic or unknown-duration fill suppresses an older brand candidate. Historical claims are not counted as multiple current patients.

Alternatives must share the exact CodeRx clinical drug and have active/prescribable package and drug records. Enterprise also restricts candidates to NDA brands/ANDA generics and valid marketing dates. Open terminology identifies active brand/nonbrand comparators without those regulatory fields. Neither is an Orange Book therapeutic-equivalence determination; substitution requires clinical, regulatory and formulary review. Biological products are not treated as NDA-to-ANDA switches in Enterprise.

For a priced estimate, require positive payer-paid brand and generic claims, positive quantity, matching source, payer, plan, clinical product, and quantity per supply day within 0.01. The generic benchmark is the median paid price per unit across currently available generic NDC claims in the last 90 days, with at least three claims and two people. Null payer/plan values match only null values. Unpriced availability remains visible and estimated savings remain null, not zero.

- Brand paid per 30 days = brand payer-paid / days supply × 30.
- Generic paid per 30 days = brand quantity / days supply × 30 × median generic payer-paid per unit.
- Estimated savings per 30 days = max(brand minus generic, 0).
- Annualized savings = daily savings × 365, assuming the current dose, continuation and prices for a full year.

Sum only `estimated_annual_savings` from `brand_generic_opportunity` with `pricing_status = 'priced_for_review'`. This estimates the priced subset of current brand users, not net realized savings or the unpriced population. Rebates, future discontinuation, benefit changes and switching costs are not modeled. No allowed amount, charged amount or patient cost sharing is used.

## Freshness and assessment date

All current outputs use today's warehouse date by default. Set `drugs_as_of_date: 'YYYY-MM-DD'` for reproducible clinical-date assessment. This does not reconstruct historical warehouse snapshots: terminology and late-arriving records are the currently loaded versions. Rebuild daily or after new input delivery to keep materialized worklists current; the package creates no schedule.

Retain both `file_date` and `ingest_datetime`, preferring file date for the displayed freshness date. A recent reload must not make an old source file look current. The latest clinical service/dispensing date is reported separately; none of these dates guarantees a complete claims feed. Missing/future dates and source age or clinical lag above 45 days are visible. Patient-level evidence dates can be older than the source's latest delivery.

Conditions recover missing ingestion metadata through source/person/claim joins to aggregated `core.medical_claim`, preventing diagnosis-to-claim-line fanout. The condition and treatment evidence dates are included in each worklist. Confirm enrollment and current medication status before acting on lagged data.

## Configuration

| Variable | Default |
| --- | --- |
| `use_coderx_enterprise` | `false` (native YAML boolean) |
| `drugs_as_of_date` | `null` = today's date |
| `drugs_episode_gap_days` | `30` |
| `drugs_stockpile_early_refills` | `false` (native YAML boolean) |
| `drugs_condition_lookback_days` | `365` |
| `drugs_uncertain_exposure_days` | `365` |
| `drugs_refill_min_fills` | `2` distinct maintenance fill dates |
| `drugs_refill_lookahead_days` | `7` |
| `drugs_refill_max_overdue_days` | `30` |
| `drugs_freshness_days` | `45` |
| `drugs_generic_lookback_days` | `90` |
| `drugs_generic_min_claims` / `drugs_generic_min_people` | `3` / `2` |

Core and Open terminology default to `target.database`, schemas `core` and `terminology`. Enterprise defaults to the Core database and `terminology`, with `coderx_enterprise_` prefix; override `drugs_coderx_database`, `drugs_coderx_schema`, and `drugs_coderx_table_prefix` as needed. Only `drugs`, `packages` and `classes` are required from either tier. All four workflows run with Open terminology. Enterprise improves regulatory availability checks and descriptive enrichment; its indication table is deliberately not required for these condition mappings.

## Validation and contributions

Run `dbt build --select package:drugs` in a nonproduction schema. Native dbt unit fixtures cover gap tolerances, early fill overlap/carryover, source isolation, uncertainty, current refill boundaries and prospective savings. Data tests enforce grains, Core row and paid reconciliation, episode coverage arithmetic and worklist/savings invariants. Run the same build with both `use_coderx_enterprise: false` and `true`. CI checks that both configurations parse; warehouse execution is required for behavioral tests.

The initial release excludes general adherence/PDC scoring, polypharmacy support, drug interactions, broad indication inference and spend decomposition. Archived prototype outputs are not part of this package.

## Method and clinical context references

The mapping scope was informed by these primary sources; the package does not implement all of their treatment recommendations:

- [OHDSI OMOP CDM drug eras](https://ohdsi.github.io/CommonDataModel/cdm54.html#drug_era).
- [Dima & Dediu (2017), AdhereR](https://doi.org/10.1371/journal.pone.0174426).
- [ADA Standards of Care 2026: pharmacologic glycemic treatment](https://doi.org/10.2337/dc26-s009).
- [AHA/ACC hypertension guideline 2025](https://doi.org/10.1161/CIR.0000000000001356).
- [AHA/ACC chronic coronary disease guideline 2023](https://doi.org/10.1161/CIR.0000000000001168).
- [GOLD 2026 report and pocket guide](https://goldcopd.org/2026-gold-report-and-pocket-guide/).
- [GINA 2025 summary guide](https://ginasthma.org/wp-content/uploads/2025/06/GINA-Summary-Guide-2025-WEB_FINAL-WMS.pdf).
