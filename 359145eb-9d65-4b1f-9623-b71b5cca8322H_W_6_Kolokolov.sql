create function extract_utm_param(url text,
param_name text)
returns text as $$
begin
    return regexp_replace(url,
'.*' || param_name || '=([^&]*).*',
'\1');
end;

$$ language plpgsql;

with facebook_ad_campaign as (
select
	a.ad_date,
	c.campaign_name,
	b.adset_name,
	a.spend,
	a.impressions,
	a.reach,
	a.clicks,
	a.leads,
	a.value,
	a.url_parameters
from 
		facebook_ads_basic_daily a
left join facebook_adset b on
			b.adset_id = a.adset_id
left join facebook_campaign c on
			c.campaign_id = a.campaign_id
where
	ad_date is not null
order by
	ad_date),
google_facrbook as (
select
	ad_date,
	campaign_name,
	adset_name,
	spend,
	impressions,
	reach,
	clicks,
	leads,
	value,
	url_parameters,
	extract_utm_param(url_parameters,
	'utm_source') as media_source
from
	facebook_ad_campaign
union all
select
	ad_date,
	campaign_name,
	adset_name,
	spend,
	impressions,
	reach,
	clicks,
	leads,
	value,
	url_parameters,
	extract_utm_param(url_parameters,
	'utm_source') as media_source
from
	google_ads_basic_daily
order by
	ad_date),
google_facrbook_total as (
select
	ad_date,
	campaign_name,
	sum(spend) as total_spend,
	sum(impressions) as total_impressions,
	sum(reach) as total_reach,
	sum(clicks) as total_clicks,
	sum(leads) as total_leads,
	sum(value) as total_value,
	media_source,
	case
		extract_utm_param(url_parameters,
		'utm_campaign')
		 when 'nan' then '0'
		when '' then '0'
		else lower(extract_utm_param(url_parameters, 'utm_campaign'))
	end as utm_parameters,
	case
		-- Prevent division by zero
		when SUM(clicks) = 0 then null
		else ROUND(SUM(spend)::DECIMAL / SUM(clicks)::DECIMAL,
		3)
	end as cpc,
	case
		-- Prevent division by zero
		when SUM(impressions) = 0 then null
		else ROUND((SUM(spend)::DECIMAL / SUM(impressions)::DECIMAL)* 1000,
		3)
	end as cpm,
	case
		-- Prevent division by zero
		when SUM(impressions) = 0 then null
		else ROUND((SUM(clicks)::DECIMAL / SUM(impressions)::DECIMAL) * 100,
		3)
	end crt,
	case
		-- Prevent division by zero
		when SUM(spend) = 0 then null
		else ROUND(((SUM(value)::DECIMAL - SUM(spend)::DECIMAL) / SUM(spend)::DECIMAL) * 100,
		3)
	end as romi
from
	google_facrbook
group by
	ad_date,
	media_source,
	campaign_name,
	url_parameters
)
select
	*
from
	google_facrbook_total
where
	ad_date is not null
order by
	ad_date asc;