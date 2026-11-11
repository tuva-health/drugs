{{ config(alias='open_drug_gap') }}
select * from {{ ref('drugs__condition_status') }} where open_drug_gap_flag=1
 and {{ 1 if drugs_enterprise() else 0 }}=1
