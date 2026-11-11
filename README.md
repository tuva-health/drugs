# Drugs

Four medication analytics workflows on top of Tuva Core: **Drug Episodes, Open Drug Gaps, Needs Refill, and Brand vs. Generic**. This standalone dbt package replaces the pharmacy mart removed from Tuva Core after v0.18.0. It does not modify Core or ship licensed terminology or real patient data.

## Install and run

Install Drugs alongside Tuva Core in the root dbt project that maps your claims
and clinical data to the Tuva Input Layer. The root project owns the Core
version; Drugs uses Core refs rather than an independently configured copy of
its source tables. The medication analytics use claims-derived records only.

The Snowflake development environment is pinned in
[`requirements-snowflake.txt`](requirements-snowflake.txt). From this repository,
install it in a virtual environment with `python -m pip install -r requirements-snowflake.txt`.
Configure the root project's Snowflake profile before running dbt.

The examples below pin the tested 1.0 development revision. No 1.0 release
tag has been published; the previous `v0.2.0` tag does not include these
changes. The public ingredient asset must be published before a fresh install
can use this automatic loading path.

```yaml
# packages.yml in the root project
packages:
  - git: https://github.com/tuva-health/tuva-core.git
    # Tested Core 1.0 integration revision; includes the CodeRx NDC fix.
    revision: 599e953e10fba61352bfb6e7d64c2a9b58335fb1
  - git: https://github.com/tuva-health/drugs.git
    revision: f965533f86e245e41218bec3993a3c152ff268ac
```

```yaml
# dbt_project.yml in the root project
vars:
  claims_enabled: true
  use_coderx_enterprise: false
  drugs_data_asset_version: '1.0.0'
```

```sh
dbt deps
dbt build --select +package:drugs
```

On a fresh installation, the build includes required upstream Core nodes and
package data assets. The public ingredient bridge loads with the package; no
separate RxNorm download, Python script, or warehouse upload is required.
Models are created in `drugs`, or `<tuva_schema_prefix>_drugs` when a prefix is
configured. The example notebook uses the unprefixed `drugs` schema.

For paid terminology, follow the [CodeRx Drug Database setup](https://thetuvaproject.com/coderx)
and provide `coderx.packages`, `coderx.drugs`, and `coderx.classes` in the dbt
target database before setting `use_coderx_enterprise: true`. Use native YAML
booleans, not quoted strings. Optional Enterprise columns and ingredient
relationships are detected separately; they are not required for the four
baseline use cases. See [Terminology capabilities](#terminology-capabilities).

## Inputs and outputs

`core.medication` is the root medication fact, restricted to `source_type = 'claims'`. `core.pharmacy_claim` supplies payer/plan, **payer-paid amount only**, refill metadata, and file/ingestion provenance, joined on medication ID, person and source. Core must already normalize paid/reversed/denied claims. No authorization count creates additional supply.

Other dependencies are `core.condition`, `core.medical_claim` (diagnosis freshness lineage), `core.patient` (death status), and `core.eligibility` (current membership context). Every patient and claim join is source-scoped. Patients with unconfirmed current enrollment remain visible with a review status; deceased patients are excluded from worklists and opportunities.

| Table | Grain / purpose |
| --- | --- |
| `drug_episode` | Source, patient, atomic RxNorm ingredient, observed episode start |
| `open_drug_gap` | Source, patient, condition; potential absence of current qualifying supply |
| `needs_refill` | Source, patient, condition; potential refill due soon or recently overdue |
| `brand_generic_opportunity` | Source, patient, current branded clinical product; availability and prospective savings |
| `medication` | Source and Core medication ID; all claim rows including unusable exposure |
| `condition_status` | All assessed source/patient/condition combinations, including unknown and not-flagged results |
| `condition_evidence` | Relevant Core condition records and freshness lineage |
| `medication_condition` | Medication/condition evidence with matched ATC rule |
| `generic_alternative` | Currently active generic NDC and clinical drug; available independently of observed claims/prices |
| `condition_summary` | Counts of gaps and refills by source and condition; reconciles to the patient worklists |
| `brand_generic_summary` | Brand, generic clinical product, switchable patients and prospective savings; full-cohort savings only when all patients are priced |
| `episode_mapping_quality` | Usable claims excluded from episodes because no ingredient mapping is available |
| `patient_context`, `source_freshness` | Enrollment, death and patient/source data freshness |
| `terminology_status` | One-row record of the selected terminology tier, available enrichment and public ingredient asset version |

Join `condition_status_id` between the condition worklists. Drill into diagnosis evidence by source/person/condition name and medication evidence by source/person/condition code. `latest_maintenance_medication_id` links directly to `medication`. Join `brand_generic_opportunity.clinical_drug_id` to `generic_alternative` to see candidate NDCs; aggregate savings from the parent opportunity table **before** expanding alternatives to avoid multiplying savings.

## Drug Episodes

The algorithm is inspired by [OHDSI drug eras](https://ohdsi.github.io/CommonDataModel/cdm54.html#drug_era) and [Dima and Dediu's published AdhereR methods](https://doi.org/10.1371/journal.pone.0174426). OHDSI uses a 30-day persistence window; AdhereR explicitly parameterizes permissible gaps and carryover. Our defaults are configurable assumptions, not clinical thresholds.

1. Require a nonfuture dispensing date, an NDC, positive integer days supply of at most 365, and no nonpositive quantity. Missing quantity does not invalidate known days supply. Unknown durations stay in `medication` but do not create exposure.
2. Group by atomic **RxNorm ingredient (IN)**, independent of strength, dosage form or brand. A dose change continues the ingredient episode if it meets the gap rule. Combination pills contribute separately to each ingredient, so moving between a combination and its separate components preserves continuity. Supply is calculated at the original clinical-product level before expanding ingredients; optional stockpiling never crosses strengths/forms. Unmapped ingredients are excluded from episodes and counted in `episode_mapping_quality`; they never silently become NDC-level episodes.
3. A fill's inclusive end is dispensing date + days supply - 1. By default early-fill overlaps are unioned, **without stockpiling**, following OHDSI's convention. Optional stockpiling carries all excess supply within the same clinical product; this is a sensitivity setting and can overestimate supply after dose/regimen changes. No carryover occurs between sources, patients, strengths or forms.
4. Compare each interval with the maximum preceding end. If the uncovered days exceed `drugs_episode_gap_days`, start a new episode. Default 30 means gaps of 0, 1 and 30 days stay in the same episode; 31 starts another. Set 0 for strictly adjacent/overlapping coverage, or 1 to allow one uncovered day.
5. Return a long table with `episode_id`, `data_source`, `person_id`, `drug_code` (RxNorm IN), `drug_name`, `start_date`, and `end_date`, plus coverage metrics. End the episode at the last estimated supply day, with no grace-period extension. Report unioned covered days and actual uncovered days separately. `active_supply_flag` is 1 only when a fill covers the assessment date, regardless of episode tolerance.

Example: a January 1 fill for 30 days ends January 30. January 31 is an adjacent refill with zero uncovered days; February 1 leaves one uncovered day. Both remain one episode under the default. That one uncovered day is still a supply gap.

Episode dates describe observed dispensing history and projected supply, not proven ingestion or original treatment initiation. No eligibility clipping removes supply. `no_later_supply_observed` is not a confirmed discontinuation; consult source freshness. Reported refills are retained as metadata because refill-number semantics vary and authorization is not a dispensing event.

## Open Drug Gaps and Needs Refill

The initial cohorts use unresolved Tuva-grouper condition records in the 365 days ending on the assessment date: Type 2 Diabetes Mellitus, Hypertension, Coronary Artery Disease, Chronic Obstructive Pulmonary Disease, Asthma, Heart Failure (CHF), and Atrial Fibrillation and Flutter (AFib). Missing/future condition dates do not qualify. Analysts can edit the versioned `drugs__condition_rule` seed; it is an auditable mapping, not a diagnosis or prescribing protocol.

| Condition | Evidence counted as related medication |
| --- | --- |
| T2D | ATC A10 glucose-lowering drugs, including semaglutide |
| HTN | ATC C02, C03, C07, C08, C09 antihypertensive classes |
| CAD | ATC B01AC antiplatelets, C10 lipid-modifying drugs, C01D cardiac vasodilators, C07 beta blockers |
| COPD / Asthma | ATC R03 obstructive-airway medications; rescue-only drugs count as treatment evidence but do not trigger scheduled refill estimates |
| CHF | Renin-angiotensin drugs, selected beta blockers, loop diuretics, MRAs, SGLT2 drugs, digoxin, ivabradine, nitrates and hydralazine |
| AFib / Flutter | Oral anticoagulants or related rate/rhythm drugs: beta blockers, diltiazem/verapamil, digoxin, and selected antiarrhythmics; aspirin and lidocaine are not counted |

The Tuva groups combine HF subtypes and AFib/flutter. These worklists do not assess ejection fraction, stroke-risk eligibility for anticoagulation, contraindications, or a complete HF regimen. A beta blocker counts as AFib-related therapy but does not establish appropriate stroke prevention.

These intentionally broad **any-related-treatment** rules answer the requested question about absent medication evidence. They do not certify guideline-concordant treatment: for example, rescue-only asthma treatment suppresses the broad open-gap flag but does not establish adequate controller treatment, and CAD antiplatelet use does not establish adequate lipid therapy. Many drugs treat several conditions. OTC aspirin, cash fills, samples, administered drugs outside the pharmacy feed and lifestyle-only management can explain an apparent gap.

`open_drug_gap` contains patients with a qualifying condition and **no supply active today**, regardless of whether a drug was ever filled. A recent qualifying claim with unknown duration, or a recent unmapped drug, yields an unable-to-assess status in `condition_status` and a null flag. Known active treatment gives a zero gap flag. A missing pharmacy feed also prevents an assessable gap. Review freshness before outreach.

`needs_refill` requires at least two distinct maintenance dispensing dates in the past 365 days, an estimated due date within the next 7 days or at most 30 days overdue, and no unresolved exposure uncertainty. The due date is the day after the last known maintenance supply ends. Current maintenance replacement therapy suppresses overdue recommendations. An active rescue inhaler alone does not suppress an overdue controller refill. Respiratory rescue-only medications are excluded from scheduled refill estimates; repeat controller/long-acting medications can qualify, with scheduled versus PRN use requiring review. The list is condition-level, so it will not flag a missing component of a multidrug regimen while another qualifying maintenance treatment covers the condition. Older overdue patients remain in Open Drug Gaps rather than being assumed to need automatic restart.

Due-soon patients need not have an open gap yet; patients due today or recently overdue can appear in both worklists. Flags are independent and evidence is retained.

## Reporting and drilldowns

`condition_summary` provides source/condition counts of `patients_with_open_gaps` and `patients_needing_refill`. Sum by condition for the headline report; filter `open_drug_gap` or `needs_refill` on that condition and source to inspect patient IDs, evidence dates and freshness. One patient can appear under several conditions. Counts remain source-scoped, not deduplicated across payers.

`condition_summary.refill_denominator_patients` is the qualifying condition
population across sources with an observed pharmacy feed, excluding known
deceased patients. It includes patients without prior fills and those whose
exposure is uncertain. `percent_needing_refill` is 100 times
`patients_needing_refill` divided by that denominator, rounded to two decimals;
it is null when the denominator is zero. `assessed_patients` has a different
scope and must not be substituted for the refill denominator.

When combining sources, sum the numerator and denominator first, then divide.
Do not average source-level percentages. Missing refill flags are not counted
as refill needs; an unflagged patient is not necessarily adequately treated.
The `latest_maintenance_medication_id` and drug name identify the usable
maintenance fill whose supply end drives the refill due date. That may differ
from the most recently dispensed medication.

The canonical [Drugs notebook](notebooks/drugs.ipynb) explains each use case
with native SQL cells, patient drilldowns and Python charts. Set the database
in its first SQL cell, then run the notebook from top to bottom. Every query
uses `drugs.table` and includes all data sources; there are no schema,
data-source or assessment-date inputs. The assessment date comes from the
mart's build. Its saved example outputs must come from an executed synthetic
build, with published synthetic data distinguished from any controlled
scenario cohort used to demonstrate known fills and prices.

The notebook is a standard `.ipynb` file. Native SQL execution and named result
binding use Snowflake notebook metadata. Python charts use pandas and
Matplotlib. Other notebook platforms may need their own SQL-result binding;
a portable file format does not establish identical execution behavior.

## Brand vs. Generic

The legacy pharmacy mart's useful distinction between catalog availability and priced opportunities is retained. Current users are identified from estimated supply **on the assessment date**. Select one latest active fill per source/person/clinical drug. A newer overlapping generic or unknown-duration fill suppresses an older brand candidate. Historical claims are not counted as multiple current patients.

Alternatives must share the exact CodeRx clinical drug and have active/prescribable package and drug records. When optional Enterprise marketing metadata is available and enabled, known marketing categories must be NDA for current brands and ANDA for generic alternatives. Generic alternatives must also have valid known marketing dates at the assessment date. Current brand exposure follows estimated on-hand supply, so a brand marketing end date does not itself erase an existing fill. A missing category uses the brand/nonbrand baseline; generic alternatives still respect known marketing dates. The screening fields expose that limitation. When optional marketing columns are absent or enrichment is disabled, the baseline uses active brand/nonbrand comparators without regulatory screening. `brand_screening_basis`, `generic_screening_basis` and `marketing_screening_applied_flag` identify which rules were applied. The opportunity-level marketing flag is 1 only when both the brand and all catalog alternatives used marketing screening. Neither is an Orange Book therapeutic-equivalence determination; substitution requires clinical, regulatory and formulary review. Biological products are not treated as NDA-to-ANDA switches when regulatory screening is applied.

For a priced estimate, require positive payer-paid brand and generic claims, positive quantity, matching source, payer, plan, clinical product, and quantity per supply day within 0.01. The generic benchmark is the median paid price per unit across currently available generic NDC claims in the last 90 days, with at least three claims and two people. Null payer/plan values match only null values. Unpriced availability remains visible and estimated savings remain null, not zero.

- Brand paid per 30 days = brand payer-paid / days supply × 30.
- Generic paid per 30 days = brand quantity / days supply × 30 × median generic payer-paid per unit.
- Estimated savings per 30 days = max(brand minus generic, 0).
- Annualized savings = daily savings × 365, assuming the current dose, continuation and prices for a full year.

Financial outputs are rounded independently to cents from the underlying daily
amounts. Do not reconstruct annual savings from an already-rounded 30-day
amount.

`brand_generic_summary` produces `brand_drug`, `generic_alternative`, `patients_who_could_switch`, priced/unpriced patient counts, and annual savings. `annual_savings_if_all_switched` is null unless every candidate is priced. `annual_savings_for_priced_patients` is an explicitly partial subtotal when prices are missing. One generic clinical product represents its potentially many generic NDCs; alternatives do not multiply patients or dollars.

Sum only `estimated_annual_savings` from `brand_generic_opportunity` with `pricing_status = 'priced_for_review'`. This estimates the priced subset of current brand users, not net realized savings or the unpriced population. Rebates, future discontinuation, benefit changes and switching costs are not modeled. No allowed amount, charged amount or patient cost sharing is used.

## Freshness and assessment date

All current outputs use today's warehouse date by default. Set `drugs_as_of_date: 'YYYY-MM-DD'` for reproducible clinical-date assessment. This does not reconstruct historical warehouse snapshots: terminology and late-arriving records are the currently loaded versions. Rebuild daily or after new input delivery to keep materialized worklists current; the package creates no schedule.

Retain both `file_date` and `ingest_datetime`, preferring file date for the displayed freshness date. A recent reload must not make an old source file look current. The latest clinical service/dispensing date is reported separately; none of these dates guarantees a complete claims feed. Missing/future dates and source age or clinical lag above 45 days are visible. Patient-level evidence dates can be older than the source's latest delivery.

Conditions recover missing ingestion metadata through source/person/claim joins to aggregated `core.medical_claim`, preventing diagnosis-to-claim-line fanout. The condition and treatment evidence dates are included in each worklist. Confirm enrollment and current medication status before acting on lagged data.

## Configuration

| Variable | Default |
| --- | --- |
| `use_coderx_enterprise` | `false` (native YAML boolean; same choice as Core) |
| `drugs_enable_enterprise_enrichment` | `true` (native YAML boolean; uses optional paid metadata when present) |
| `drugs_data_asset_version` | `1.0.0` |
| `drugs_coderx_database` / `drugs_coderx_schema` | dbt target database / `coderx`; advanced Enterprise source overrides |
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

## Terminology capabilities

All four use cases run with the three CodeRx Open assets supplied by Core and
the package's public RxNorm ingredient bridge. Selecting Enterprise routes the
three base tables to the target database's `coderx` schema, matching Core's default sources. Advanced `drugs_coderx_database` and `drugs_coderx_schema` overrides change the Drugs input location only; keep them aligned with the terminology used to build Core. Missing paid base relations cause
a failure; unmatched paid records do not silently fall back to Open.

`drugs_enable_enterprise_enrichment: true` allows the package to use optional
Enterprise drug descriptions, ingredient relationships and marketing metadata
when available. Set it to `false` to use the paid base tables without those
additional fields. An absent optional table or column leaves baseline
analytics available and is recorded in `drugs.terminology_status`:

| `capability_status` | Meaning |
| --- | --- |
| `open_baseline` | Core's Open assets and the public ingredient bridge |
| `enterprise_enrichment_disabled` | Paid base tables selected; optional enrichment explicitly off |
| `enterprise_base_only` | Paid base tables available without optional enrichment |
| `enterprise_partially_enriched` | Some optional Enterprise capabilities available |
| `enterprise_enriched` | All supported optional capabilities available |

The table includes separate flags for drug details, ingredient relationships
and marketing checks. Review these flags and `generic_alternative` screening
fields before comparing results across installations. Enterprise indications
are not required for the seven condition mappings, which use versioned ATC
rules; these rules do not infer an individual patient's prescribing indication.

## Public ingredient terminology

Both modes use a package-owned bridge derived from
[NLM RxNorm Current Prescribable Content](https://www.nlm.nih.gov/research/umls/rxnorm/docs/prescribe.html).
It maps drug concepts to atomic RxNorm IN ingredients. The public map is
preferred; optional Enterprise ingredients can extend historical concept
coverage. Unmapped concepts remain visible in `episode_mapping_quality`.

`drugs_data_asset_version` selects one pinned package data-asset snapshot,
independently of the Drugs code version and Core's data-asset version.
Maintainers own source acquisition, transformation and publication; users load
the released bridge through the package build. No licensed CodeRx content is
included in the public bridge. Changing the selected snapshot requires
reloading its seed and rebuilding dependent models.

## Validation and contributions

Run `dbt build --select package:drugs` in a nonproduction schema. Native dbt unit fixtures cover gap tolerances, early fill overlap/carryover, source isolation, uncertainty, current refill boundaries and prospective savings. Data tests enforce grains, Core row and paid reconciliation, episode coverage arithmetic and worklist/savings invariants. Validate Open, paid base-only and paid enriched configurations against the same Core input. Parsing is a configuration check; warehouse builds and their unit/data tests establish runtime behavior. Review actual test and notebook execution evidence for the code revision being adopted.

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

- [AHA/ACC/HFSA heart failure guideline 2022](https://doi.org/10.1161/CIR.0000000000001063).
- [ACC/AHA AFib guideline 2023](https://www.jacc.org/doi/10.1016/j.jacc.2023.08.017).

## Migrating from 0.2

The 1.0 contract changes installation, terminology sources and public assets.
Install Core in the root project, remove the former Core-source overrides and
manual ingredient-source setup, and use the configuration above. Rebuild the
full mart rather than mixing old tables with new worklists.

Episode, condition-assessment and brand-opportunity IDs are regenerated using
Core's stable, collision-safe ID convention. Do not assume that an identifier
from 0.2 will match its 1.0 counterpart. Refresh downstream extracts and joins
that persist these IDs. Natural source/patient/drug or condition keys remain
the basis for comparing the two builds.

The refill denominator now explicitly excludes known deceased patients and
sources without an observed pharmacy feed. Percentages may change from prior
reports that used every assessed patient. Review the denominator and unknown
counts alongside the flagged worklist.
