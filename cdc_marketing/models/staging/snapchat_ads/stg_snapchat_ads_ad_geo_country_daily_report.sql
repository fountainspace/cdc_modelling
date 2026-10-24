select *
from {{ source('snapchat_ads', 'ad_geo_country_daily_report') }}
