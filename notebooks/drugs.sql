-- Databricks notebook source
-- MAGIC %md # Drugs: four use cases
-- MAGIC Run the mart before refreshing this notebook. Set the schema and optional source/patient filters below. Medication exposure is estimated from dispensed supply; episode tolerance does not fill supply gaps. Worklists require review of evidence, enrollment and freshness. All financials are payer-paid; savings are prospective, before rebates.

-- COMMAND ----------


DECLARE OR REPLACE VARIABLE mart STRING DEFAULT 'YOUR_CATALOG.drugs';
DECLARE OR REPLACE VARIABLE selected_source STRING DEFAULT '';
DECLARE OR REPLACE VARIABLE selected_person STRING DEFAULT '';

-- COMMAND ----------


-- MAGIC %md ## Data freshness and scope
-- MAGIC Latest file, ingestion and service dates answer different questions. These are observed dates, not certified claims completion. All patient-level views remain inside the warehouse.

-- COMMAND ----------


SELECT * FROM IDENTIFIER(mart || '.source_freshness') WHERE selected_source='' OR data_source=selected_source ORDER BY data_source;

-- COMMAND ----------


SELECT data_source, exposure_status, count(*) AS medication_claims,
 round(sum(paid_amount),2) AS payer_paid
FROM IDENTIFIER(mart || '.medication')
WHERE selected_source='' OR data_source=selected_source
GROUP BY data_source,exposure_status ORDER BY data_source,medication_claims DESC;

-- COMMAND ----------


-- MAGIC %md ## 1. Drug Episodes
-- MAGIC Clinical drug = same ingredient, strength and form; brand/generic versions can share an episode. Default tolerance is 30 uncovered days, with no stockpiling. Covered/uncovered days include projected supply after the assessment date where applicable.

-- COMMAND ----------


SELECT data_source,count(*) AS episodes,count(DISTINCT person_id) AS patients,
 sum(restart_flag) AS restarted_episodes,sum(active_supply_flag) AS episodes_with_supply_today,
 round(avg(episode_span_days),1) AS mean_span_days,round(avg(uncovered_days),1) AS mean_uncovered_days
FROM IDENTIFIER(mart || '.drug_episode') WHERE selected_source='' OR data_source=selected_source
GROUP BY data_source ORDER BY patients DESC;

-- COMMAND ----------


SELECT therapy_name,count(*) AS episodes,count(DISTINCT struct(data_source,person_id)) AS source_patient_pairs,
 sum(restart_flag) AS restarted_episodes,sum(active_supply_flag) AS episodes_with_supply_today
FROM IDENTIFIER(mart || '.drug_episode') WHERE selected_source='' OR data_source=selected_source
GROUP BY therapy_name ORDER BY episodes_with_supply_today DESC LIMIT 25;

-- COMMAND ----------


-- MAGIC %md ## 2. Open Drug Gaps
-- MAGIC A recent Tuva condition with no related supply active today. These are potential review opportunities, not prescribing recommendations. Unknown exposure is reported separately. Related treatment does not imply a complete guideline-concordant regimen.

-- COMMAND ----------


SELECT data_source,condition_name,gap_status,outreach_readiness_status,count(*) AS patients
FROM IDENTIFIER(mart || '.condition_status') WHERE selected_source='' OR data_source=selected_source
GROUP BY data_source,condition_name,gap_status,outreach_readiness_status
ORDER BY data_source,condition_name,patients DESC;

-- COMMAND ----------


SELECT condition_name,gap_history,outreach_readiness_status,count(*) AS patients,
 min(condition_freshness_date) AS oldest_condition_evidence_delivery,
 max(condition_freshness_date) AS newest_condition_evidence_delivery
FROM IDENTIFIER(mart || '.open_drug_gap') WHERE selected_source='' OR data_source=selected_source
GROUP BY condition_name,gap_history,outreach_readiness_status ORDER BY patients DESC;

-- COMMAND ----------


-- MAGIC %md ## 3. Needs Refill
-- MAGIC At least two maintenance fill dates, due within seven days or up to 30 days overdue. Condition-level replacement therapy suppresses overdue flags. Confirm scheduled use and whether treatment was intentionally stopped.

-- COMMAND ----------


SELECT data_source,condition_name,refill_status,outreach_readiness_status,count(*) AS patients,
 min(days_overdue) AS least_days_overdue,max(days_overdue) AS most_days_overdue
FROM IDENTIFIER(mart || '.needs_refill') WHERE selected_source='' OR data_source=selected_source
GROUP BY data_source,condition_name,refill_status,outreach_readiness_status ORDER BY patients DESC;

-- COMMAND ----------


SELECT latest_maintenance_drug_name,condition_name,refill_status,count(*) AS patients
FROM IDENTIFIER(mart || '.needs_refill') WHERE selected_source='' OR data_source=selected_source
GROUP BY latest_maintenance_drug_name,condition_name,refill_status ORDER BY patients DESC LIMIT 25;

-- COMMAND ----------


-- MAGIC %md ## 4. Brand vs. Generic
-- MAGIC Catalog availability and priceability are separate. Annualized savings assume 365 days at current utilization and observed payer-paid prices. Aggregate parent opportunities before expanding candidate NDCs. Do not treat null savings as zero or infer savings for the unpriced population.

-- COMMAND ----------


SELECT data_source,pricing_status,count(*) AS current_brand_products,
 count(DISTINCT person_id) AS current_brand_patients,sum(generic_available_flag) AS products_with_generics,
 round(sum(estimated_savings_per_30_days),2) AS savings_per_30_days,
 round(sum(estimated_annual_savings),2) AS annualized_savings
FROM IDENTIFIER(mart || '.brand_generic_opportunity') WHERE selected_source='' OR data_source=selected_source
GROUP BY data_source,pricing_status ORDER BY annualized_savings DESC NULLS LAST;

-- COMMAND ----------


SELECT data_source,clinical_drug_name,count(*) AS current_brand_patients,
 round(sum(estimated_savings_per_30_days),2) AS savings_per_30_days,
 round(sum(estimated_annual_savings),2) AS annualized_savings
FROM IDENTIFIER(mart || '.brand_generic_opportunity')
WHERE pricing_status='priced_for_review' AND (selected_source='' OR data_source=selected_source)
GROUP BY data_source,clinical_drug_name ORDER BY annualized_savings DESC LIMIT 25;

-- COMMAND ----------


-- MAGIC %md ## Evidence drilldown
-- MAGIC Set both selected_source and selected_person above to inspect one patient. Empty filters return no patient rows. Check condition, medication, supply and file dates before taking action.

-- COMMAND ----------


SELECT * FROM IDENTIFIER(mart || '.condition_status') WHERE selected_source<>'' AND selected_person<>'' AND data_source=selected_source AND person_id=selected_person ORDER BY condition_name;

-- COMMAND ----------


SELECT * FROM IDENTIFIER(mart || '.condition_evidence') WHERE selected_source<>'' AND selected_person<>'' AND data_source=selected_source AND person_id=selected_person ORDER BY condition_date DESC;

-- COMMAND ----------


SELECT * FROM IDENTIFIER(mart || '.medication_condition') WHERE selected_source<>'' AND selected_person<>'' AND data_source=selected_source AND person_id=selected_person ORDER BY dispensing_date DESC;

-- COMMAND ----------


SELECT b.opportunity_id,b.drug_name,b.pricing_status,b.estimated_annual_savings,
 a.generic_ndc_code,a.generic_drug_name,a.alternative_basis
FROM IDENTIFIER(mart || '.brand_generic_opportunity') b
LEFT JOIN IDENTIFIER(mart || '.generic_alternative') a ON b.clinical_drug_id=a.clinical_drug_id
WHERE selected_source<>'' AND selected_person<>'' AND b.data_source=selected_source AND b.person_id=selected_person;
-- Savings repeat across alternatives here: do not sum this drilldown.
