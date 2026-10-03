/*
    Tables
*/

WITH source_data AS (

    SELECT * FROM {{ source('facebook_ads', 'campaigns') }}

),

/*
    Transformations
*/

formatted AS (

    SELECT
        -- FK
        CAST(campaign_id AS STRING) AS campaign_id,

        -- Details
        CAST(campaign_name AS STRING) AS campaign_name,

        -- Metadata
        CAST(campaign_updated_at AS TIMESTAMP) AS campaign_updated_at,
        current_timestamp()
    FROM
        source_data
)

SELECT * FROM formatted