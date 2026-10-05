{{ config(
    materialized='table' if flags.FULL_REFRESH else 'incremental',
    incremental_strategy='microbatch',
    event_time='ad_date',
    begin='2025-01-01' if target.name == 'production' else modules.datetime.datetime.now().isoformat(),
    batch_size='month',
    lookback=1,
    on_schema_change= 'fail'
) }}


/*
    Tables
*/

WITH all_ad_stats AS (

    SELECT * FROM {{ ref('stg_facebook_ads_basic_all_levels') }}

),

/*
    Formatted
*/

formatted AS (

    SELECT
        -- FK
        ad_id,

        -- Metrics
        ad_spend,
        ad_impressions,
        ad_clicks,

        -- Metadata
        ad_date
    FROM
        all_ad_stats

)

SELECT * FROM formatted
