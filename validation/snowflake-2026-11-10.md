# Snowflake validation — November 10, 2026

The CodeRx-only 1.0 development package was tested on Tuva Snowflake Dev with
dbt Core 1.12.6, dbt-snowflake 1.12.4 and Tuva Core commit
`599e953e10fba61352bfb6e7d64c2a9b58335fb1`. This is the tested Core integration
revision including the CodeRx NDC ambiguity fix, not a new Core release tag.
No customer data was used.

## Current build results

| Configuration | Seed run | Drugs build | Separate scenario assertions |
| --- | ---: | ---: | ---: |
| CodeRx Open | 10 succeeded | 150 succeeded/passed | 7 tests and 2 hooks passed |
| CodeRx Enterprise | 10 succeeded | 150 succeeded/passed | 7 tests and 2 hooks passed |

Each build contained 30 successful results and 120 passing tests. Scenario assertions
were also selected explicitly so every fixture-based integration check ran. The Drugs builds read the
verified Tuva Core facts; these counts are not a claim that the entire Core
project consists of 150 nodes.

Open was configured with a nonexistent paid-source schema. It still built and
passed, demonstrating that this path does not depend on Enterprise tables.
Its clinical tables were empty with their required columns and disabled
capability flags. Medication enrichment and economic assertions remained
available. The same seven scenario tests run in both modes: Open asserts the
clinical boundary, while Enterprise verifies the expected clinical outputs.

Enterprise required the licensed packages, drugs, classes and ingredients
relations. Separate negative tests verified clear compilation errors for:

- The three complete base tables without the required ingredients relation.
- A minimal Core projection missing columns required by Drugs.
- A missing required paid relation.

These failures are expected contract checks, not successful analytics runs.

## Synthetic data and assertions

The integration project preserves 291 published small synthetic pharmacy
claims and their $45,827.28 payer-paid total. Their missing days supply is
retained. A separate controlled cohort adds 57 pharmacy claims, 34 diagnosis
claims and 42 patient/source records. Scenario data passes through Tuva Core's
Input Layer rather than being written directly to Core output tables.

Enterprise assertions cover all seven condition cohorts, unknown versus zero
flags, refill denominators and percentages, coherent refill evidence,
rescue-versus-maintenance handling, source isolation and 30/31-day episode
gaps. Condition rules use exact CodeRx ingredient IDs; tests also cover the
explicit arformoterol rule and avoid accidental substring matches for
related drug names. The policy uses CodeRx classes and ingredients rather than
assuming vendor indication relationships are complete prescribing rules.

Economic assertions verify two priced Lipitor scenarios with $1,350.50 and
$985.50 in annualized payer-paid savings, totaling $2,336. A separate source
without a comparable generic benchmark retains availability and null savings.
The newer-generic-switch scenario is excluded from current brand opportunities.
These are constructed validation outcomes, not findings about a real population.

## Notebook and runtime scope

The canonical notebook contains current Enterprise results. All 13 analytical
SQL queries succeeded in Snowflake, and all six Python cells ran locally
against those captured results, producing five chart images. The separate
Open pass also executed all 13 analytical queries and six Python cells. Its
seven clinical queries returned no rows, and all three clinical chart cells
displayed an explicit Enterprise-required message. Open retained the two
nonclinical charts. The public database setup cell remains a placeholder. This workflow validates the queries and chart
calculations; it does not establish a new native Snowflake or Databricks
notebook import test.

Parse CI checks compilation and schema placement without executing warehouse
queries. Databricks and other warehouse runtimes were not revalidated in this
change. Core emits an existing duplicate-description YAML deprecation warning.

## Terminology and release status

All drug facts come from CodeRx. The repository contains the Tuva analytic
condition policy and synthetic fixtures. Paid tables are loaded separately by the licensed
user. Core's Open assets retain Core's normal loading process. No package tag
or GitHub release has been created.
