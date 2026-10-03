/*
    Tables
*/

WITH all_ads AS (

    SELECT *
    FROM {{ ref('stg_facebook_ads_ad_history') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ad_id
        ORDER BY ad_updated_at DESC
    ) = 1

),

ad_groups AS (

    SELECT *
    FROM {{ ref('stg_facebook_ads_ad_set_history') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ad_group_id
        ORDER BY ad_group_updated_at DESC
    ) = 1

),

all_campaigns AS (

    SELECT *
    FROM {{ ref('stg_facebook_ads_campaign_history') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY campaign_id
        ORDER BY campaign_updated_at DESC
    ) = 1

),

account_details AS (

    SELECT * FROM {{ ref('stg_facebook_ads_account_history') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY account_id
        ORDER BY account_updated_at DESC
    ) = 1

),

/*
    Transformations
*/

join_all_details AS (

    SELECT
        all_ads.*,
        ad_groups.ad_group_name,
        all_campaigns.campaign_name,
        account_details.account_name,
        GREATEST(
            all_ads.ad_updated_at,
            ad_groups.ad_group_updated_at,
            all_campaigns.campaign_updated_at,
            account_details.account_created_at
        ) AS ad_detail_updated_at
    FROM
        all_ads
    LEFT JOIN
        ad_groups
        ON
            all_ads.ad_group_id = ad_groups.ad_group_id
    LEFT JOIN
        all_campaigns
        ON
            all_ads.campaign_id = all_campaigns.campaign_id
    LEFT JOIN
        account_details
        ON
            all_ads.account_id = account_details.account_id

),


/*
    Formatted
*/

formatted AS (

    SELECT
        ad_id,

        -- FK
        ad_group_id,
        campaign_id,
        account_id,
        
        -- Details
        ad_name,
        ad_group_name,
        campaign_name,
        account_name,
        'Paid Social' AS channel_name,
        -- Metadata
        ad_detail_updated_at,
        'facebook_ads' AS data_src
    FROM
        join_all_details

)

SELECT * FROM formatted