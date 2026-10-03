/*
    Tables
*/


SELECT
    *,
    null AS new_id
FROM {{ ref('int_facebook_ads_details') }}
