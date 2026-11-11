# Core-to-Drugs integration scenarios

This root dbt project maps the published **small Tuva synthetic claims** and a separate, deterministic scenario cohort into Tuva Core's Input Layer. Core builds its claims-derived tables before Drugs reads them through dbt refs. The project does not populate `core.medication` or `core.condition` directly.

The controlled cohort has 42 patient/source records, 57 pharmacy claims, and 34 diagnosis claims. It is deliberately small enough to inspect. Scenario financial inputs populate payer `paid_amount`; other financial columns are null. The original published claims are passed through unchanged.

The assessment date is fixed at **November 10, 2026**. Claims are fabricated test data, not clinical guidance. The medications illustrate the package's existing related-treatment rules; they are not proposed treatment regimens.

## Expected outcomes

| Scenario | Expected result |
|---|---|
| Seven conditions, each with current, absent, overdue, and unknown-duration treatment | Exact patient-level flags for T2D, HTN, CAD, COPD, Asthma, CHF, and AFib |
| Ivabradine, hydralazine, and dabigatran | Their intended ingredient-specific rules match through Core and the RxNorm ingredient bridge |
| Current albuterol with overdue repeated montelukast fills | No broad open treatment gap; one potential maintenance refill |
| Older 90-day lisinopril fill and newer 30-day hydralazine fill | The November 15 refill due date points to the older lisinopril fill |
| Deceased patient and source without pharmacy claims | Retained for assessment reporting, excluded from the refill denominator |
| Unknown days supply and no prior fills in a source with pharmacy data | Included in the denominator; unknown refill status stays unknown |
| Overlapping fills followed by 30 and 31 uncovered days | First episode January 1–April 19: 79 covered days, 30 uncovered days; second episode May 21–June 19 |
| Repeated person and claim IDs across sources | Distinct histories, episode identities, and refill assessments |
| Two current Lipitor 20 mg users with an exact atorvastatin 20 mg benchmark | Median generic payer-paid cost $0.30/unit; annualized savings $1,350.50 and $985.50, totaling **$2,336** |
| A newer generic fill after an earlier brand fill | The switched patient is excluded from current brand opportunities |
| The same brand in another source with no generic claims | Generic availability is visible, but estimated savings remain null |

These are fixed assertions in the `expected_*.csv` fixtures and singular SQL tests. They are expected controlled outcomes until a warehouse build passes, not findings about a real population.

The sources are `scenario_clinical`, `scenario_other`, `scenario_no_rx`, `scenario_economics`, and `scenario_economics_other`. The economics cohort is separate so its deliberately chosen prices cannot be altered by the clinical-cohort fills. Its four generic claims belong to three people and have payer-paid unit costs $0.20, $0.30, $0.40, and $0.30.

The selected NDCs and drug/ingredient RxCUIs are listed in `seeds/scenario_products.csv`. They were checked against both CodeRx Open and the licensed snapshot on November 10, 2026. The Lipitor NDC also has the NDA metadata required by the optional Enterprise marketing screen. No licensed bulk terminology is included in this project.

## Setup and execution

Install the repository's `requirements-snowflake.txt`, configure a local dbt profile, and check out Tuva Core alongside Drugs. Set `TUVA_CORE_PATH` when the Core checkout is elsewhere. CI pins Core commit `599e953e10fba61352bfb6e7d64c2a9b58335fb1`; a version string on Core's main branch is not a release-tag assertion.

```bash
cd integration_tests
export TUVA_CORE_PATH=/path/to/tuva-core
dbt deps --profiles-dir ~/.dbt
dbt parse --no-partial-parse --profiles-dir ~/.dbt --profile snowflake-dev
```

Before building, provision Core's required versioned assets into the selected schema prefix: terminology, value sets, provider data, and the small synthetic data. Use Core's documented loaders for a fresh environment, or copy already-loaded assets into an isolated validation schema. Do not reload unchanged Core assets merely to rerun Drugs tests.

The default prefix is `drugs_validation_20261110_open`. Override `tuva_schema_prefix` for each additional mode. This keeps Core, Drugs, scenario inputs, and connector outputs isolated from ordinary development tables. The fixed dates and scenario expectations should remain unchanged for this suite.

Load only the package-owned inputs and changed Drugs assets, then build the complete Core-to-Drugs graph:

```bash
dbt seed --profiles-dir ~/.dbt --profile snowflake-dev \
  --select package:drugs_integration_tests package:drugs
dbt build --profiles-dir ~/.dbt --profile snowflake-dev \
  --select package:drugs_integration_tests package:the_tuva_project package:drugs \
  --exclude resource_type:seed
dbt test --profiles-dir ~/.dbt --profile snowflake-dev \
  --select tag:drugs_scenarios
```

The final `dbt test` command is required: excluding seed nodes from `dbt build` also excludes tests that depend on the expected-result seeds. Running `dbt test` without that exclusion executes all seven scenario assertions and does not reload seeds.

For Enterprise validation, supply native boolean `use_coderx_enterprise: true`, configure the three user-managed CodeRx tables required by Core, and select a separate schema prefix. Drugs can use the same three tables with no optional enrichment, or add the licensed ingredient and marketing fields described in the package README. Keep the Core and Drugs terminology snapshots aligned. Set `drugs_enable_enterprise_enrichment: false` to exercise the explicit opt-out path. Apply the same variables to seeding and building.

Inspect `run_results.json` and the seven `drugs_scenarios` singular tests before reporting success. The parse CI only checks compilation and schema placement; it does not connect to a warehouse or prove Snowflake/Databricks runtime compatibility.
