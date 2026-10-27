{# Shared column descriptions, referenced from model and source YAML with {{ doc('<name>') }} #}

{# Identifiers #}

{% docs ad_id %}
Identifier of the ad. Unique per row in the ad details models; one row per ad and day in the stats models.
{% enddocs %}

{% docs ad_group_id %}
Identifier of the ad group (Facebook ad set) the ad belongs to.
{% enddocs %}

{% docs campaign_id %}
Identifier of the campaign the ad belongs to.
{% enddocs %}

{% docs account_id %}
Identifier of the ad account that owns the ad.
{% enddocs %}

{% docs ad_detail_id %}
Identifier of the Snapchat ad the stats row belongs to.
{% enddocs %}

{# Attributes #}

{% docs ad_name %}
Name of the ad as set in the ad platform.
{% enddocs %}

{% docs ad_group_name %}
Name of the ad group (Facebook ad set) as set in the ad platform.
{% enddocs %}

{% docs campaign_name %}
Name of the campaign as set in the ad platform.
{% enddocs %}

{% docs account_name %}
Name of the ad account as set in the ad platform.
{% enddocs %}

{% docs ad_status %}
Delivery status of the ad in the ad platform (e.g. active, paused).
{% enddocs %}

{% docs ad_currency_code %}
ISO 4217 code of the currency the ad account is billed in, and so the currency of `ad_spend`.
{% enddocs %}

{% docs ad_country %}
Country the ad was delivered in.
{% enddocs %}

{% docs channel_name %}
Marketing channel the ad is reported under. Always `Paid Social` for Facebook ads.
{% enddocs %}

{% docs data_src %}
Ad platform the row comes from (e.g. `facebook_ads`).
{% enddocs %}

{# Metrics #}

{% docs ad_spend %}
Amount spent on the ad that day, in the ad account's currency (`ad_currency_code`).
{% enddocs %}

{% docs ad_impressions %}
Number of times the ad was shown that day.
{% enddocs %}

{% docs ad_clicks %}
Number of clicks on the ad that day.
{% enddocs %}

{# Dates and timestamps #}

{% docs ad_date %}
Day the stats were recorded for.
{% enddocs %}

{% docs ad_updated_at %}
When this version of the ad record was last updated in the ad platform.
{% enddocs %}

{% docs ad_group_updated_at %}
When this version of the ad group record was last updated in the ad platform.
{% enddocs %}

{% docs campaign_updated_at %}
When this version of the campaign record was last updated in the ad platform.
{% enddocs %}

{% docs account_created_at %}
When the ad account was created in the ad platform.
{% enddocs %}

{% docs account_updated_at %}
When this version of the ad account record was last updated in the ad platform.
{% enddocs %}

{% docs ad_detail_updated_at %}
Latest change across the ad, its ad group, campaign and account (the greatest of their update timestamps and the account creation time). Drives incremental loads of `dim_facebook_ads_details`.
{% enddocs %}
