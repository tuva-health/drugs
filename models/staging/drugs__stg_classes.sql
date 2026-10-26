select distinct cast(drug_id as {{ dbt.type_string() }}) as drug_id,
       atc_1_code, atc_1_name, atc_2_code, atc_2_name,
       atc_3_code, atc_3_name, atc_4_code, atc_4_name
from {{ drugs_coderx('classes') }}
