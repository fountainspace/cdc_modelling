
WITH source_data AS (

    SELECT * FROM  {{ source('facebook_ads', 'accounts') }}
    {{ add_rows_limit() }} 
    


),

/*
    Transformations
*/

formatted AS (

    SELECT
        -- FK
        CAST(account_id AS STRING) AS account_id,

        -- Details
        CAST(account_name AS STRING) AS account_name,
        CAST(ad_currency_code AS STRING) AS ad_currency_code,

        -- Metadata
        CAST(account_created_at AS TIMESTAMP) AS account_created_at,
        CAST(account_updated_at AS TIMESTAMP) AS account_updated_at
    FROM
        source_data
)

SELECT * FROM formatted
