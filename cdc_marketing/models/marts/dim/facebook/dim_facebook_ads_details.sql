/*

    Tables

*/

{{
    config(
        materialized='incremental',
        unique_key='ad_id',
        incremental_strategy='merge',
        on_schema_change='fail',
        cluster_by=['data_src']
    )
}}

SELECT *

FROM {{ ref('int_facebook_ads_details') }}

{% if is_incremental() %}

    -- On the first run, is_incremental() is false, so the model builds the full table.
    -- On subsequent runs, only records from the incremental lookback window are processed.
    --
    -- The existing target table ({{ this }}) is used to determine the latest
    -- ad_detail_updated_at that has already been loaded.
    --
    -- A 7-day lookback is applied to reprocess recent records and capture
    -- late-arriving or updated records.
    --
    -- LEAST() prevents a future ad_detail_updated_at in the target table
    -- from moving the incremental boundary into the future.
    --
    -- COALESCE() provides a fallback date if the target table contains no
    -- non-NULL ad_detail_updated_at values.

    WHERE ad_detail_updated_at >= (
        SELECT
            LEAST(
                COALESCE(
                    MAX(ad_detail_updated_at),
                    DATE("2022-01-01")
                ),
                CURRENT_DATE()
            ) - INTERVAL 7 DAY
        FROM {{ this }}
    )

{% endif %}
