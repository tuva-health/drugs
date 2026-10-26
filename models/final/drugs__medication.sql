{{ config(alias='medication') }}
with primary_class as (
 select *,row_number() over(partition by drug_id order by atc_4_code,atc_3_code) as class_rank
 from {{ ref('drugs__stg_classes') }}
), enriched as (
 select m.medication_id,m.source_type,m.person_id,m.data_source,m.claim_id,m.claim_line_number,
        m.dispensing_date,m.ndc_code,m.days_supply,m.quantity,
        c.payer,c.plan,c.dispensing_provider_id,c.prescribing_provider_id,
        c.paid_amount,c.refills as reported_refills,
        coalesce(c.ingest_datetime,m.ingest_datetime) as ingest_datetime,
        {{ drugs_optional_column(source('tuva_core','pharmacy_claim'), 'file_date', 'c', 'date') }} as file_date,
        c.member_month_id,
        p.drug_id,d.drug_name,d.clinical_drug_id,d.clinical_drug_name,
        d.ingredient_id,d.ingredient_name,d.dose_form_name,
        coalesce(p.brand_flag,d.brand_flag) as brand_flag,p.marketing_category,
        d.terminology_tier,
        cl.atc_4_code as primary_atc_4_code,cl.atc_4_name as primary_atc_4_name,
        case when d.clinical_drug_id is not null then concat('clinical:',d.clinical_drug_id)
             else concat('ndc:',m.ndc_code) end as therapy_id,
        coalesce(d.clinical_drug_name,d.drug_name,m.ndc_description) as therapy_name,
        case when d.clinical_drug_id is not null then 'clinical_drug' else 'ndc' end as therapy_grain,
        
        case when m.dispensing_date is null then 'missing_dispensing_date'
             when m.dispensing_date > {{ drugs_as_of() }} then 'future_dispensing_date'
             when m.days_supply is null then 'missing_days_supply'
             when m.days_supply <= 0 or m.days_supply <> floor(m.days_supply) then 'nonpositive_days_supply'
             when m.days_supply > 365 then 'days_supply_above_365'
             when m.quantity <= 0 then 'nonpositive_quantity'
             when m.ndc_code is null then 'missing_drug_code'
             else 'usable' end as exposure_status,
        cast(case when p.drug_id is not null then 1 else 0 end as {{ dbt.type_int() }}) as terminology_matched_flag
 from {{ source('tuva_core','medication') }} m
 left join {{ source('tuva_core','pharmacy_claim') }} c
   on m.medication_id=c.pharmacy_claim_id and m.data_source=c.data_source and m.person_id=c.person_id
 left join {{ ref('drugs__stg_packages') }} p on m.ndc_code=p.ndc_code
 left join {{ ref('drugs__stg_drugs') }} d on p.drug_id=d.drug_id
 left join primary_class cl on p.drug_id=cl.drug_id and cl.class_rank=1
 where m.source_type='claims'
)
select *,case when exposure_status='usable' then days_supply/30.0 end as thirty_day_equivalent_fills
from enriched
