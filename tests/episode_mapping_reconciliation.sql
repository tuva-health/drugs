select data_source
from {{ ref('drugs__episode_mapping_quality') }}
where medication_claim_count <> usable_supply_claim_count + unusable_supply_claim_count
   or usable_supply_claim_count <> episode_mapped_claim_count + usable_claims_without_episode_mapping
   or usable_claims_without_ingredient > usable_claims_without_episode_mapping
   or usable_claims_without_dose_form > usable_claims_without_episode_mapping
