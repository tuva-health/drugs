with counts as (
 select count(distinct condition_code) as conditions,
 count(distinct case when refill_eligible_flag=1 then condition_code end) as refill_conditions
 from {{ ref('drugs__condition_rule') }}
)
select * from counts where conditions<>68 or refill_conditions<>7
