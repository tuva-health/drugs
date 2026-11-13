# Integration tests

This root dbt project passes Tuva's published small synthetic claims and a separate, fabricated scenario cohort through the Tuva Input Layer, Core, and Drugs. It never writes fabricated rows directly into Core output tables. The assessment date is fixed at November 10, 2026.

The fixtures exercise:

- All 68 condition mappings through Core's diagnosis grouper.
- Annual dispensing evidence, missing days supply, mixed classes, and source isolation.
- Seven chronic refill cohorts, repeated-product history, due dates, denominators, and unknown results.
- Complete ingredient-combination/dose-form episodes, overlapping supply, and permissible gaps.
- Current brand/generic opportunities, observed switches, payer-paid pricing, and unpriced candidates.

The CSVs are small test inputs and expected results. They are not runtime drug terminology or estimates about a real population. Native dbt unit tests supply additional boundary cases without loading licensed data into Git.

## Run

Install `requirements-snowflake.txt`, configure your local dbt profile, and check out Tuva Core alongside this repository. CI uses the immutable Core revision recorded in `.github/workflows/parse.yml`. Set `TUVA_CORE_PATH` if your Core checkout is elsewhere.

```sh
cd integration_tests
dbt deps
```

Provision Core's normal versioned terminology, value-set, provider, and small synthetic assets for the selected schema prefix. The following commands reuse those assets, seed the test fixtures and condition policy, then build the relevant Core-to-Drugs graph:

```sh
dbt seed --select package:drugs package:drugs_integration_tests \
  --vars '{use_coderx_enterprise: false, tuva_schema_prefix: drugs_test_open}'
dbt build --select package:the_tuva_project package:drugs package:drugs_integration_tests \
  --exclude resource_type:seed \
  --vars '{use_coderx_enterprise: false, tuva_schema_prefix: drugs_test_open}'
dbt test --select tag:drugs_scenarios \
  --vars '{use_coderx_enterprise: false, tuva_schema_prefix: drugs_test_open}'
```

Run the explicit final test command: excluding seeds from a build can also exclude assertions that depend on expected-result seeds.

Repeat with `use_coderx_enterprise: true` and a separate prefix, such as `drugs_test_enterprise`. Enterprise requires the licensed `coderx.packages`, `coderx.drugs`, and `coderx.classes` tables in the target database, with the full drug fields needed for episodes. Both modes must pass gap, refill, economic, and Core reconciliation assertions. Enterprise additionally checks episode results; Open checks that episode tables are empty.

Keep connection profiles, credentials, downloaded terminology, compiled SQL, and run artifacts outside Git. The repository's CI parses both modes and checks schema placement and boolean configuration; warehouse execution is a separate validation step. Successful parsing alone does not establish runtime compatibility.
