# Changelog

## 1.0.0 (unreleased)

Drugs installs alongside Tuva Core in the root dbt project and focuses on
four workflows: ingredient episodes, potential open medication gaps,
potential refills, and brand-to-generic opportunities. Core refs establish
the dependency order; Core source locations are not configured separately.

CodeRx is the sole source of drug facts. The single
`use_coderx_enterprise` toggle selects the terminology tier and capabilities.
Open supports medication enrichment and brand-to-generic candidates.
Enterprise enables ingredient episodes, condition gaps, refill worklists and
paid marketing checks. All four licensed source relations and their required
columns are validated; missing Enterprise inputs fail without fallback.

Clinical tables exist but are empty under Open. `terminology_status` exposes
that boundary through capability flags so an unavailable workflow is not
mistaken for a population with no review needs. Drug ingredients come from
exact CodeRx identifiers,
not drug-name parsing. Tuva's explicit seven-condition related-treatment rules
remain analytic policy; vendor `may_treat` / `may_prevent` relationships are
not treated as complete prescribing rules or verified FDA-label evidence.

Refill reporting includes patient denominators and percentages. The fill that
determines a refill due date is also retained as the supporting evidence.
Current rescue medication does not hide an overdue maintenance refill.
Savings use payer-paid amounts and are independently rounded to cents.

This is a breaking change from 0.2.0. Episode, condition-status and opportunity
IDs use Core's collision-safe hashing; rebuild downstream joins from the new
tables. The separate Core source overrides and standalone Databricks
deployment scripts are removed. A single SQL/Python notebook replaces the
old SQL-only example. No 1.0.0 release has been published.
