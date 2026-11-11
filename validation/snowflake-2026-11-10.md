# Snowflake validation — November 10, 2026

The 1.0 development package was exercised on Tuva Snowflake Dev with dbt Core
1.12.6, dbt-snowflake 1.12.4 and Tuva Core commit
`599e953e10fba61352bfb6e7d64c2a9b58335fb1`. This is a tested Core 1.0 integration
revision including the CodeRx NDC ambiguity fix, not a new Core release tag.
No customer data was used.

| Configuration | Baseline mart build | Controlled scenario build | Explicit scenario assertions |
| --- | ---: | ---: | ---: |
| CodeRx Open | 133 passed | 529 passed, including Core | 7 passed |
| Enterprise, three minimal Core tables | 133 passed | 134 passed | 7 passed |
| Enterprise, full optional enrichment | 133 passed | 529 passed, including Core | 7 passed |
| Enterprise, enrichment explicitly disabled | 133 passed | 134 passed | 7 passed |

Build counts include models, tests and hooks. Every reported result passed or
succeeded; none failed or was skipped. The baseline mart runs deferred to
separately verified Core outputs. Open and full Enterprise scenario runs built
the complete claims Core-to-Drugs graph; minimal/off scenario runs used the same
verified Enterprise Core facts and rebuilt Drugs against their own terminology
settings. Each of the four explicit scenario assertion runs also passed its
two startup hooks. The assertions run separately because excluding seeds from
`dbt build` can indirectly exclude tests that depend on expected-result seeds.

The four `terminology_status` rows reported the intended modes:
`open_baseline`, `enterprise_base_only`, `enterprise_enriched`, and
`enterprise_enrichment_disabled`. Only the full configuration enabled all
three enrichment flags. The minimal schema had only the documented Core
columns and no optional ingredients relation.

All modes retained the 291 published synthetic pharmacy records and
$45,827.28 payer-paid total. Their days supply remained missing, yielding zero
usable exposure records. The separate scenario cohort added 57 pharmacy claims,
34 diagnoses and 42 patient/source records. All scenario dispensings passed
through Core exactly once with expected NDC/RxNorm codes, quantities, days
supply and payer-paid values.

The fixed assertions verified all seven disease cohorts, unknown versus zero
flags, refill denominators and percentages, coherent refill evidence,
rescue-versus-maintenance handling, source isolation and 30/31-day episode
gaps. The two priced Lipitor scenarios produced $1,350.50 and $985.50 in
annualized payer-paid savings; the separate source without a benchmark
retained generic availability and null savings. Published source claims were
not altered to obtain those outcomes.

A separate cross-mode query audit reconciled medication counts and payer-paid
totals, episode counts and covered days, condition counts/denominators, and
brand/generic patient counts and savings across all four settings. Terminology
catalog size and screening provenance are allowed to differ between tiers.

The canonical notebook SQL ran in Snowflake against the verified Open outputs.
Python chart cells ran locally against those actual results and saved standard
notebook outputs. This validates the queries and chart calculations; it does
not claim a fresh native Snowflake or Databricks notebook import test.

## Asset and release prerequisites

The new public ingredient bridge is derived only from NLM's November 2, 2026
Current Prescribable Content archive. Its published archive checksum was
verified. Deterministic generation produced 74,827 unique drug/ingredient
relationships across 57,803 concepts; header/type validation and the unmodified
package loader hook passed on DuckDB. Snowflake tests loaded the same compressed
CSV bytes into isolated test schemas using PUT/COPY.

The public `data-marts/drugs/1.0.0/` candidate **has not been published**. The
prepared sync plan has no deletions and requires approved, authenticated Tuva
S3/GCS/Azure publication sessions. Publish and verify that candidate before
merging or advertising the automatic fresh-install path. Code and asset release
status remain separate; no package tag or GitHub release was created.

Parse CI validates both tiers, schema placement and rejection of a quoted
stockpile boolean. It does not execute a warehouse build. Databricks and other
warehouse runtimes were not revalidated in this change. Core emits an existing
duplicate-description YAML deprecation warning; no Drugs test warning remains.
