select *
from {{ ref('stg_facebook_ads_account_history') }}
where account_id is null
