-- models/marts/mart_powerplay_analysis.sql
--
-- Powerplay (overs 1-6) performance by batsman and bowler.
-- Specialist mart for the powerplay deep-dive page.

{{
  config(
    materialized = 'table',
    partition_by = {
      "field": "season",
      "data_type": "int64",
      "range": {"start": 2008, "end": 2025, "interval": 1}
    },
    labels = {"layer": "mart", "domain": "powerplay"}
  )
}}

with

deliveries as (

    select
        d.*,
        m.season,
        m.match_date,
        m.venue,
        m.city
    from {{ ref('stg_deliveries') }} d
    inner join {{ ref('stg_matches') }} m using (match_id)
    where d.phase = 'powerplay'
      and not d.is_super_over
      and m.season >= {{ var('min_season') }}

),

-- Powerplay batting
pp_batting as (

    select
        batsman                                             as player_name,
        batting_team                                        as team,
        season,
        'batting'                                           as role,

        count(distinct match_id)                            as matches,
        sum(case when is_legal_ball then 1 else 0 end)      as balls_faced,
        sum(batsman_runs)                                   as runs_scored,
        sum(case when is_boundary_4 then 1 else 0 end)      as fours,
        sum(case when is_boundary_6 then 1 else 0 end)      as sixes,
        sum(case when is_dot_ball then 1 else 0 end)        as dot_balls,
        sum(case when is_wicket and player_dismissed = batsman then 1 else 0 end) as dismissals

    from deliveries
    group by 1, 2, 3, 4

),

-- Powerplay bowling
pp_bowling as (

    select
        bowler                                              as player_name,
        bowling_team                                        as team,
        season,
        'bowling'                                           as role,

        count(distinct match_id)                            as matches,
        sum(case when is_legal_ball then 1 else 0 end)      as balls_bowled,
        sum(total_runs - bye_runs - legbye_runs)            as runs_conceded,
        sum(case when is_boundary_4 then 1 else 0 end)      as fours_conceded,
        sum(case when is_boundary_6 then 1 else 0 end)      as sixes_conceded,
        sum(case when is_dot_ball then 1 else 0 end)        as dot_balls,
        sum(case when is_wicket
                  and dismissal_kind not in ('run out', 'retired hurt')
                 then 1 else 0 end)                         as wickets

    from deliveries
    group by 1, 2, 3, 4

),

batting_with_rates as (

    select
        *,
        {{ calculate_strike_rate('runs_scored', 'balls_faced') }}   as strike_rate,
        {{ safe_divide('dot_balls * 100', 'balls_faced') }}         as dot_ball_pct,
        {{ safe_divide('(fours * 4 + sixes * 6) * 100', 'runs_scored') }} as boundary_pct,
        null::float64                                               as economy_rate

    from pp_batting
    where balls_faced >= 20

),

bowling_with_rates as (

    select
        *,
        null::float64                                               as strike_rate,
        {{ safe_divide('dot_balls * 100', 'balls_bowled') }}        as dot_ball_pct,
        null::float64                                               as boundary_pct,
        {{ economy_rate('runs_conceded', 'balls_bowled') }}         as economy_rate

    from pp_bowling
    where balls_bowled >= 18   -- At least 3 full overs in powerplay

)

select * from batting_with_rates
union all
select * from bowling_with_rates
