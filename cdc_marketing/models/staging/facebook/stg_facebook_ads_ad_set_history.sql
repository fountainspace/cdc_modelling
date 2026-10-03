/*
    Tables
*/

WITH source_data AS (

    SELECT * FROM {{ source('facebook_ads', 'adgroups') }}

),

/*
    Transformations
*/

formatted AS (

    SELECT
        -- FK
        CAST(ad_group_id AS STRING) AS ad_group_id,

        -- Details
        CAST(ad_group_name AS STRING) AS ad_group_name,

        -- Metadata
        CAST(ad_group_updated_at AS TIMESTAMP) AS ad_group_updated_at
    FROM
        source_data
)

SELECT * FROM formatted