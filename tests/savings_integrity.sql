select opportunity_id
from {{ ref('drugs__brand_generic_opportunity') }}
where
    (pricing_status <> 'priced_for_review' and (
        estimated_annual_savings is not null or estimated_savings_per_30_days is not null
        or brand_paid_per_30_days is not null or generic_paid_per_30_days is not null
    ))
    or (pricing_status = 'priced_for_review' and (
        estimated_annual_savings is null or estimated_savings_per_30_days is null
        or brand_paid_per_30_days is null or generic_paid_per_30_days is null
        or generic_available_flag <> 1
        or benchmark_claim_count < {{ var('drugs_generic_min_claims') }}
        or benchmark_person_count < {{ var('drugs_generic_min_people') }}
    ))
    or estimated_annual_savings < 0
    -- Each period is rounded independently from the underlying rate.
    or abs(estimated_annual_savings - round(greatest(0,
        (paid_amount - quantity * generic_paid_per_unit) / days_supply * 365), 2)) > 0.000001
    or abs(estimated_savings_per_30_days - round(greatest(0,
        (paid_amount - quantity * generic_paid_per_unit) / days_supply * 30), 2)) > 0.000001
    or abs(brand_paid_per_30_days - round(paid_amount / days_supply * 30, 2)) > 0.000001
    or abs(generic_paid_per_30_days - round(quantity / days_supply * 30 * generic_paid_per_unit, 2)) > 0.000001
