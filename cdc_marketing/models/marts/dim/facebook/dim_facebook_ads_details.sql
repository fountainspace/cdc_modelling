/*
    Tables
*/


    SELECT *,
    null as new_id
    FROM {{ ref('int_facebook_ads_details') }}


