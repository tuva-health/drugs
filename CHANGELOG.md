# Changelog

## 1.0.0 (unreleased)

Drugs installs alongside Tuva Core and supports four use cases, in order:
Brand vs. Generic, Needs Refill, Open Drug Gaps, and Drug Episodes.

CodeRx Open supports the first three use cases. Enterprise provides broader
drug coverage and enables episodes. `use_coderx_enterprise` is the single tier
setting. Enterprise requires the full packages, drugs and classes source
tables; missing required data fails without fallback.

Open Drug Gaps covers 68 Tuva-grouper conditions. It compares condition evidence
and any related claims dispensing within the same 365-day window. Days supply
and current active exposure are not required. Possible class matches and
unmapped medication evidence remain uncertain. This replaces the earlier
seven-condition current-supply gap definition.

Needs Refill retains seven chronic conditions, repeated maintenance fills and
known supply. Reports include condition denominators and percentages, with the
fill supporting each estimated due date. Brand-to-generic estimates use payer-paid
amounts and show priced and unpriced candidates separately.

Episodes now follow the complete CodeRx ingredient combination and dose form,
independent of strength. Combination products are not split into atomic
ingredients. The default permissible gap remains 30 uncovered days.

This is a breaking change from 0.2.0 and earlier 1.0 development revisions.
Episode, condition-status and opportunity IDs use Core's collision-safe hashing;
episode grain and condition scope have changed. Rebuild the mart and downstream
joins. A single SQL/Python notebook replaces the old SQL-only example. Separate
Core source overrides and standalone Databricks deployment scripts are removed.
No 1.0.0 release has been published.
