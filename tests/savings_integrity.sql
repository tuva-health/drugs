select opportunity_id from {{ ref('drugs__brand_generic_opportunity') }} where
 (pricing_status<>'priced_for_review' and estimated_annual_savings is not null)
 or (pricing_status='priced_for_review' and (estimated_annual_savings is null or generic_available_flag<>1 or benchmark_claim_count<{{ var('drugs_generic_min_claims') }} or benchmark_person_count<{{ var('drugs_generic_min_people') }}))
 or estimated_annual_savings<0 or abs(estimated_annual_savings-estimated_savings_per_30_days/30*365)>0.01
