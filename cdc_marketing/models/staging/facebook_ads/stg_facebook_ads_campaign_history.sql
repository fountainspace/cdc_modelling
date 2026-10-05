/*
    Tables
*/

WITH source_data AS (

    SELECT * FROM {{ source('facebook_ads', 'campaigns') }}
{{ add_rows_limit() }}),

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
        CAST(campaign_updated_at AS TIMESTAMP) AS campaign_updated_at

    FROM
        source_data
)

SELECT * FROM formatted
