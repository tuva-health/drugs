# Drugs

The Drugs data mart builds on Tuva Core's `core.medication` table to identify medication support and payer-paid savings opportunities. It replaces the pharmacy mart included in Tuva Core through v0.18.0.

| Use case | What it answers | Drug / condition coverage | CodeRx Open | CodeRx Enterprise |
| --- | --- | --- | --- | --- |
| **Brand vs. Generic** | Who currently uses a brand with a generic alternative, and what could the payer save? | <ul><li>Open: 21,440 drug products¹</li><li>Enterprise: 66,471 drug products¹</li></ul> | Available | Available |
| **Needs Refill** | Who may need a refill soon or is recently overdue? | <ul><li>7 chronic conditions</li><li>Open: 21,440 drug products¹</li><li>Enterprise: 66,471 drug products¹</li></ul> | Available | Available |
| **Open Drug Gaps** | Who has a documented condition but no related dispensing in the past year? | <ul><li>68 Tuva-grouper conditions</li></ul> | Available | Available |
| **Drug Episodes** | What are the start and end dates of a course of a drug? | <ul><li>Enterprise: 66,471 drug products¹</li><li>Grouped by complete ingredient combination and dose form</li></ul> | Requires Enterprise | Available |

¹ Product counts describe the evaluated CodeRx catalog snapshots, not fixed coverage guarantees, counts of eligible switching candidates, or counts of distinct ingredients or episode groups.

- Refill reporting covers Type 2 Diabetes, Hypertension, Coronary Artery Disease, COPD, Asthma, Heart Failure, and Atrial Fibrillation and Flutter.
- Drug gaps cover 68 Tuva-grouper conditions across cardiovascular, metabolic, mental health, neurologic, respiratory, gastrointestinal and other condition families. The [versioned condition rules](seeds/drugs__condition_rule.csv) define the complete scope.

## Install

Add both packages to the root dbt project that maps your data to the Tuva Input Layer. The root project owns the Tuva Core version.

```yaml
# packages.yml
packages:
  - git: https://github.com/tuva-health/tuva-core.git
    # Core 1.0 integration revision, including the CodeRx NDC fix.
    revision: 599e953e10fba61352bfb6e7d64c2a9b58335fb1
  - git: https://github.com/tuva-health/drugs.git
    revision: 61ab86a7d30153aef1b653ea42d1f5f642aa7105
```

```yaml
# dbt_project.yml
vars:
  claims_enabled: true
  use_coderx_enterprise: false
```

```sh
dbt deps
dbt build --select +package:drugs --indirect-selection cautious
```

This is the 1.0 development branch; a 1.0 release has not been published. For local Snowflake development, install the versions in [requirements-snowflake.txt](requirements-snowflake.txt).

Open terminology loads through Tuva Core. To use purchased Enterprise data, follow the [CodeRx Drug Database setup](https://www.thetuvaproject.com/coderx), load the full `coderx.packages`, `coderx.drugs` and `coderx.classes` tables in the target database, and set `use_coderx_enterprise: true` as a YAML boolean. Missing required Enterprise tables or columns produce an error; the package does not substitute Open data. No licensed CodeRx data is distributed in this repository.

The package requests the custom schema `drugs`, or `<tuva_schema_prefix>_drugs` with a Tuva prefix. The root project's `generate_schema_name` policy determines the final name; dbt's default also adds `target.schema`. The notebook expects the final schema to be `drugs`.

## Outputs and definitions

### 1. Brand vs. Generic

`brand_generic_opportunity` lists current brand users, including products without a catalog generic. Filter `generic_available_flag = 1` for switching candidates; `brand_generic_summary` already applies this filter. Each source/patient/clinical drug appears once. Alternatives share the same CodeRx clinical drug: ingredient, strength and form. They require clinical and formulary review, not an assumption of therapeutic equivalence.

Package-level availability and generic price benchmarks require canonical 11-digit NDCs. Core's RxNorm fallback can support product, class and episode mapping, but does not reconstruct package-level marketing or pricing evidence.

Enterprise also counts products explicitly labeled `NDA AUTHORIZED GENERIC`. In `generic_alternative`, `alternative_basis = 'active_authorized_generic_same_clinical_drug'` identifies these separately from ANDA candidates and baseline nonbrand matches. Active/prescribable, marketing-date and same-clinical-drug checks still apply.

Savings use **payer-paid amount only**. The benchmark is the median generic paid amount per unit over the previous 90 days, matching source, payer, plan, clinical drug and quantity per supply day. The default requires at least three claims from two patients. Current use and pricing require usable days supply.

`brand_generic_summary` reports the brand, generic alternative, patients who could switch and estimated annual savings. Unpriced patients remain visible. `annual_savings_if_all_switched` is null unless every candidate has a supported price; `annual_savings_for_priced_patients` is the priced subtotal. Annualization assumes continued treatment at current utilization and prices. Rebates and switching costs are not modeled.

### 2. Needs Refill

`needs_refill` lists potential refill needs for the seven chronic conditions above. It requires at least two distinct maintenance dispensing dates for the same clinical product in the past year, usable days supply, and an estimated refill due within **7 days** or no more than **30 days overdue**. The due date is the day after supply ends. This is one candidate per condition: current maintenance supply can suppress an overdue component of a multidrug regimen. It does not identify every individual drug refill. Rescue-only therapy does not establish a scheduled refill need.

Repeated fills from a curated mixed ATC class may remain candidates with `refill_class_confidence = 'possible'`. The care manager must confirm the indication and whether use is scheduled or as needed.

`condition_summary` provides `patients_needing_refill`, `refill_denominator_patients` and `percent_needing_refill`. The denominator includes living patients with the condition in sources with an observed pharmacy feed, including people with no prior fills or uncertain supply. Sum numerators and denominators before calculating percentages across sources. Other conditions are outside refill scope.

### 3. Open Drug Gaps

`open_drug_gap` lists patients with a supported Tuva-grouper condition recorded in the past **365 days** and no related claims dispensing in that **same fixed 365-day window**, including the assessment date. Any qualifying class counts: this is one condition-level check, not a separate requirement to take each class. Completed courses count, and days supply or active treatment today is not required.

The 68-condition policy maps Tuva conditions to CodeRx ATC classes. Some classes contain products unrelated to the condition. Possible-class evidence and unmapped or undated medication evidence remain uncertain rather than proving treatment or a gap. A missing source pharmacy feed also prevents a definite gap. `condition_status`, `condition_evidence` and `medication_condition` retain the assessment and supporting records; `condition_summary` gives counts by source and condition.

These are potential gaps for review. The screen does not establish treatment adequacy or a missing component of a multidrug regimen. Non-drug management, OTC products, samples and cash fills may explain the absence of claims. CodeRx indication rows are not used as complete prescribing rules.

### 4. Drug Episodes

`drug_episode` requires Enterprise and groups fills by **complete ingredient combination and dose form**, independent of strength or brand. A combination product stays one combination; switching its ingredients or dose form starts a separate track. `drug_code` is the CodeRx ingredient identifier, usually an RxNorm IN or MIN code; vendor pack/group identifiers are not represented as a single RxCUI.

The long table includes `episode_id`, `data_source`, `person_id`, `drug_code`, `drug_name`, `dose_form_id`, `dose_form_name`, `start_date` and `end_date`. By default, supply ends on dispensing date + days supply − 1. Overlaps are unioned without double counting. By default, up to **30 uncovered days** can connect fills; a 31-day gap starts a new episode. Uncovered days remain uncovered and the tolerance does not extend supply.

The method draws on [OHDSI drug eras](https://ohdsi.github.io/CommonDataModel/cdm54.html#drug_era) and [AdhereR](https://doi.org/10.1371/journal.pone.0174426). Missing duration or ingredient/form mapping does not create an episode. Open keeps the episode output columns but returns no episode rows; check `terminology_status` before interpreting empty results.

## Configuration and data freshness

| Variable | Default | Purpose |
| --- | --- | --- |
| `use_coderx_enterprise` | `false` | Select CodeRx tier and enable episodes |
| `drugs_as_of_date` | Current warehouse date | Reproducible assessment date |
| `drugs_episode_gap_days` | `30` | Maximum uncovered days within an episode |
| `drugs_stockpile_early_refills` | `false` | Carry early supply forward within a clinical product |
| `drugs_refill_min_fills` | `2` | Minimum distinct maintenance fill dates |
| `drugs_refill_lookahead_days` / `drugs_refill_max_overdue_days` | `7` / `30` | Refill due-date window |
| `drugs_generic_lookback_days` | `90` | Generic pricing lookback |
| `drugs_generic_min_claims` / `drugs_generic_min_people` | `3` / `2` | Minimum pricing evidence |
| `drugs_freshness_days` | `45` | Flag older files and dispensing lag for review |

All medication exposure comes from claims-derived `core.medication`. Additional Core tables supply payer-paid amounts, condition evidence, death/enrollment status and provenance. Patient identities and joins include `data_source`; a person in two sources may be counted twice. Deceased patients are excluded from current worklists.

Worklists retain file dates and ingestion timestamps. File date takes precedence so reloading an old file does not make it appear current. Freshness flags support review; they do not certify complete claims capture. Rebuild as data arrives to keep materialized results current. A fixed assessment date does not recreate a historical warehouse snapshot.

## Notebook

[notebooks/drugs.ipynb](notebooks/drugs.ipynb) explains all four use cases with SQL, tables and Python charts. Set only the database in its first SQL cell. Queries use `drugs.table` and include all data sources. The standard notebook uses Snowflake named SQL results; other platforms may need their own result bindings. Synthetic scenarios illustrate the calculations and are not population findings.
