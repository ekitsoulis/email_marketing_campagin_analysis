--1. Incremental Spend by Segment--
create or replace view `Email_Margeting.campaign_uplift` as
with avg_spend as (
  select
    segment,
    avg(spend) as avg_spend
  from `Email_Margeting.treatment`
  group by segment
)

select 
  a.segment,
  round(a.avg_spend, 3) as avg_spend,
  round(a.avg_spend - (select b.avg_spend from avg_spend as b where segment = 'No E-Mail'), 3) as incremental_spend
from avg_spend as a
where a.segment != 'No E-Mail';

select*from `Email_Margeting.campaign_uplift`;

-- 2. Supporting metrics by treatment. --
select 
  segment,
  count (*) as customers,
  round(avg(spend), 3) as avg_spend,
  round(avg(conversion) * 100, 3) as conversion_rate,
  round(avg(visit) * 100, 3) as visit_rate
from `Email_Margeting.treatment`
group by segment;

-- 3. Actual spend by converted customers --
select 
  segment,
  count (*) as customers,
  sum(conversion) as converters,
  round(sum(spend)/ nullif(sum(conversion),0), 2) as spend_per_converter
from `Email_Margeting.treatment`
group by segment;

  -- 4. Checking customers past behavior --
select
  segment,
  count(*) as customers,
  round(avg(recency), 2) as avg_recency,
  round(avg(history), 2) as avg_historic_spend
from `Email_Margeting.treatment`
group by segment;

-- 5. Checking if the proportions of other feature are in order. --
select
  segment,
  round(avg(mens) * 100, 2) as avg_mens,
  round(avg(womens) * 100, 2) as avg_womens,
  round(avg(newbie) * 100, 2) as avg_newbies,
from `Email_Margeting.treatment`
group by segment;

select
  segment,
  channel,
  count(*) as customers,
  round(count(*) * 100.0 / sum(count(*)) over (partition by segment), 2) as pct_within_segment
from `Email_Margeting.treatment`
group by segment, channel
order by segment, channel;

select
  segment,
  zip_code,
  count(*) as customers,
  round(count(*) * 100 / sum(count(*)) over (partition by segment), 2) as pct_by_zipcode
from `Email_Margeting.treatment`
group by segment, zip_code
order by segment, zip_code;

-- 6. Calculating Variability -- 
select 
  segment,
  count(*) as customers,
  round(avg(spend), 3) as avg_spend,
  round(stddev_samp(spend), 3) as stddev_spend
from `Email_Margeting.treatment`
group by segment;

-- 7. Calculating Standard Error and Confidence Intervals --

with group_stats as(
  select
    segment,
    count(spend) as spending_customers,
    round(avg(spend), 3) as avg_spend,
    round(stddev_samp(spend), 3) as sd_spend
  from `Email_Margeting.treatment`
  where segment in ('Mens E-Mail', 'No E-Mail', 'Womens E-Mail')
  group by segment
),
comparison as (
  select
  t.segment as treatment,
  c.segment as control,
  round(t.avg_spend - c.avg_spend, 3) as incrementalspend,
  round(sqrt(pow(t.sd_spend, 2) / t.spending_customers + pow(c.sd_spend, 2) / c.spending_customers), 3) as standard_error
from group_stats as t
cross join group_stats as c
where (t.segment = 'Mens E-Mail'
   and c.segment = 'No E-Mail')
  or
  (t.segment = 'Womens E-Mail'
   and c.segment = 'No E-Mail')
  or
  (t.segment = 'Mens E-Mail'
   and c.segment = 'Womens E-Mail'))
   
select
    treatment,
    control,
    round(incrementalspend, 3) as incremental_spend,
    round( standard_error, 3) as standard_error,
    round(incrementalspend - 1.96*standard_error, 3) as ci_lower,
    round( incrementalspend + 1.96*standard_error, 3) as ci_upper
from comparison;