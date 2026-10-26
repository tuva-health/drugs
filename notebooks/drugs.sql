-- Databricks notebook source
-- MAGIC %md # Drugs: four simple examples
-- MAGIC Each section shows the SQL and its result. Counts identify review opportunities, not confirmed prescribing needs. Patient identifiers are specific to a data source. Current means the mart's latest build date; review freshness in the patient lists.

-- COMMAND ----------

USE CATALOG YOUR_CATALOG;
USE SCHEMA drugs;

-- Leave source blank for all claims sources. Change condition to drill into another row.
DECLARE OR REPLACE VARIABLE selected_source STRING DEFAULT '';
DECLARE OR REPLACE VARIABLE selected_condition STRING DEFAULT 'Heart Failure';

-- COMMAND ----------

-- MAGIC %md ## 1. Drug episodes
-- MAGIC One row per patient, ingredient and episode. Drug code is an RxNorm ingredient code. Changes in dose, form or brand stay together; combination pills contribute to each ingredient. Default continuity allows 30 uncovered days, without counting those days as active supply.

-- COMMAND ----------

SELECT episode_id, data_source, person_id,
       drug_code, drug_name, start_date, end_date
FROM drug_episode
WHERE selected_source = '' OR data_source = selected_source
ORDER BY data_source, person_id, drug_name, start_date
LIMIT 25;

-- COMMAND ----------

-- MAGIC %md ## 2. Open drug gaps — counts by condition
-- MAGIC A recent condition with no related medication supply active today. CHF uses Tuva's **Heart Failure** group; AFib uses **Atrial Fibrillation and Flutter**. This is absence of any related therapy, not missing guideline components. AFib rate/rhythm therapy does not establish appropriate stroke prevention.

-- COMMAND ----------

SELECT condition_name AS condition,
       SUM(patients_with_open_gaps) AS number_of_gaps
FROM condition_summary
WHERE selected_source = '' OR data_source = selected_source
GROUP BY condition_name
ORDER BY number_of_gaps DESC;

-- COMMAND ----------

-- MAGIC %md ### Patients behind a condition's count
-- MAGIC Change `selected_condition` in the first cell. The list below shows the first 20 patients, with diagnosis and pharmacy evidence freshness. Uncertain exposure is retained in `condition_status` rather than asserted as a gap.

-- COMMAND ----------

SELECT data_source, person_id, condition_name,
       last_condition_date, gap_history,
       condition_freshness_date, patient_rx_freshness_date,
       source_rx_freshness_date, source_clinical_lag_days,
       outreach_readiness_status
FROM open_drug_gap
WHERE condition_name = selected_condition
  AND (selected_source = '' OR data_source = selected_source)
ORDER BY CASE WHEN outreach_readiness_status = 'current_record_review' THEN 0 ELSE 1 END,
         data_source, person_id
LIMIT 20;

-- COMMAND ----------

-- MAGIC %md ## 3. Needs refill — counts by condition
-- MAGIC Repeated maintenance fills, due in the next 7 days or up to 30 days overdue. These are condition-level potential refill needs, including CHF and AFib. Confirm that the treatment is still intended and scheduled.

-- COMMAND ----------

SELECT condition_name AS condition,
       SUM(patients_needing_refill) AS number_needing_refill
FROM condition_summary
WHERE selected_source = '' OR data_source = selected_source
GROUP BY condition_name
ORDER BY number_needing_refill DESC;

-- COMMAND ----------

-- MAGIC %md ### Patients behind the refill count
-- MAGIC The same condition selector controls this list. A negative days-overdue value means the refill is due soon.

-- COMMAND ----------

SELECT data_source, person_id, condition_name,
       latest_maintenance_drug_name AS last_maintenance_drug,
       estimated_refill_due_date, days_overdue, refill_status,
       treatment_evidence_file_date, treatment_evidence_ingest_datetime,
       source_rx_freshness_date, outreach_readiness_status
FROM needs_refill
WHERE condition_name = selected_condition
  AND (selected_source = '' OR data_source = selected_source)
ORDER BY CASE WHEN outreach_readiness_status = 'current_record_review' THEN 0 ELSE 1 END,
         days_overdue DESC, data_source, person_id
LIMIT 20;

-- COMMAND ----------

-- MAGIC %md ## 4. Brand → generic
-- MAGIC The generic alternative has the same ingredient, strength and form. Counts show current patient/product opportunities. Dollar amounts are **annualized payer-paid savings**, before rebates, assuming continued use at the current dose and prices. Clinical equivalence and coverage still need review.
-- MAGIC
-- MAGIC `annual_savings_if_all_switched` is only filled when every candidate has a supported price. `annual_savings_for_priced_patients` shows the known subtotal; it must not be presented as savings for the unpriced patients. Each patient/product is counted once, regardless of how many generic NDCs exist.

-- COMMAND ----------

SELECT brand_drug, generic_alternative,
       SUM(patients_who_could_switch) AS number_who_could_switch,
       SUM(patients_without_savings_estimate) AS number_without_price,
       ROUND(SUM(annual_savings_for_priced_patients), 2)
         AS annual_savings_for_priced_patients,
       CASE WHEN SUM(patients_without_savings_estimate) = 0
            THEN ROUND(SUM(annual_savings_for_priced_patients), 2)
       END AS annual_savings_if_all_switched
FROM brand_generic_summary
WHERE selected_source = '' OR data_source = selected_source
GROUP BY brand_drug, generic_alternative
ORDER BY annual_savings_for_priced_patients DESC NULLS LAST
LIMIT 25;

-- COMMAND ----------

-- MAGIC %md ## Data used for these examples
-- MAGIC The dates below describe the loaded data, not a certified claims-completion date. Ingredient mapping exclusions are visible in `episode_mapping_quality`. Rebuild the mart after new deliveries to refresh current lists.

-- COMMAND ----------

SELECT data_source, assessment_date,
       source_rx_file_date, source_rx_ingest_datetime,
       source_latest_fill_date
FROM source_freshness
WHERE selected_source = '' OR data_source = selected_source
ORDER BY data_source;
