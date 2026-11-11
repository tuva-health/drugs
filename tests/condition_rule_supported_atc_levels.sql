-- CodeRx provides ATC levels 1-4. A level-5 prefix can never match this source.
select rule_id
from {{ ref('drugs__condition_rule') }}
where atc_prefix is null or length(atc_prefix)>5
