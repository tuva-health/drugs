# Changelog

## 1.0.0 (unreleased)

Drugs now installs alongside Tuva Core in the root dbt project and focuses on
four outputs: ingredient episodes, potential open medication gaps, potential
refills, and brand-to-generic opportunities. Core refs establish the dependency
order; source tables are no longer configured independently of Core.

Both CodeRx tiers use the package-owned public RxNorm ingredient bridge. The
shared `use_coderx_enterprise` variable selects the terminology tier. Optional
paid product details, ingredient relationships and marketing metadata are
detected separately and can be disabled with
`drugs_enable_enterprise_enrichment: false`. `terminology_status` and screening
fields show what was available and applied.

Condition reporting includes patient denominators and refill percentages.
Ingredient-specific CHF and AFib rules match the supported ATC hierarchy.
Refill evidence identifies the same maintenance fill that determines the due
date, and an active rescue medication does not hide an overdue controller.
Savings use payer-paid amounts and are rounded independently to cents.

This is a breaking change from 0.2.0. Episode, condition-status and opportunity
IDs now use Core's collision-safe hashing, so regenerate downstream joins from
the rebuilt tables. The separate Core source overrides and standalone
Databricks deployment scripts were removed. Use a root dbt project with Core
and Drugs installed together. A single SQL/Python notebook replaces the old
SQL-only example.

No 1.0.0 release has been published. The public ingredient asset must be
published and verified before a fresh installation can load it automatically.
