-- models/marts/mart_team_season_performance.sql
--
-- One row per (team, season) with win/loss record, toss stats,
-- chase vs. defend record, and home/away splits.
-- Primary mart for the "Season Overview" dashboard page.

{{
  config(
    materialized = 'table',
    partition_by = {
      "field": "season",
      "data_type": "int64",
      "range": {"start": 2008, "end": 2025, "interval": 1}
    },
    cluster_by = ["team"],
    labels = {"layer": "mart", "domain": "team"}
  )
}}

with

match_results as (

    select * from {{ ref('int_match_results') }}
    where season >= {{ var('min_season') }}

),

-- Unpivot: one row per team per match (each match appears twice)
team_match_view as (

    select
        match_id,
        season,
        match_date,
        venue,
        city,
        toss_winner,
        toss_decision,
        toss_winner_won_match,
        first_innings_score,
        second_innings_score,
        chase_successful,
        target_tier,

        team1                                       as team,
        team2                                       as opposition,
        case when winner = team1 then true else false end as won,
        case when toss_winner = team1 then true else false end as won_toss,
        case when first_innings_team = team1 then 'bat_first' else 'chase' end as strategy

    from match_results

    union all

    select
        match_id,
        season,
        match_date,
        venue,
        city,
        toss_winner,
        toss_decision,
        toss_winner_won_match,
        first_innings_score,
        second_innings_score,
        chase_successful,
        target_tier,

        team2                                       as team,
        team1                                       as opposition,
        case when winner = team2 then true else false end as won,
        case when toss_winner = team2 then true else false end as won_toss,
        case when first_innings_team = team2 then 'bat_first' else 'chase' end as strategy

    from match_results

),

aggregated as (

    select
        team,
        season,

        -- Record
        count(*)                                        as matches_played,
        sum(case when won then 1 else 0 end)            as wins,
        sum(case when not won then 1 else 0 end)        as losses,

        -- Toss
        sum(case when won_toss then 1 else 0 end)       as toss_wins,
        sum(case when won_toss and won then 1 else 0 end) as toss_win_and_match_win,

        -- Bat first vs chase
        sum(case when strategy = 'bat_first' then 1 else 0 end) as bat_first_matches,
        sum(case when strategy = 'bat_first' and won then 1 else 0 end) as bat_first_wins,
        sum(case when strategy = 'chase' then 1 else 0 end) as chase_matches,
        sum(case when strategy = 'chase' and won then 1 else 0 end) as chase_wins,

        -- Scores
        avg(case when strategy = 'bat_first' then first_innings_score else null end) as avg_score_batting_first,
        avg(case when strategy = 'chase' then second_innings_score else null end) as avg_score_chasing

    from team_match_view

    group by 1, 2

),

with_derived as (

    select
        *,

        -- Win percentage
        {{ safe_divide('wins * 100', 'matches_played') }}           as win_pct,

        -- Toss conversion rate
        {{ safe_divide('toss_win_and_match_win * 100', 'toss_wins') }} as toss_win_conversion_pct,

        -- Bat first win rate
        {{ safe_divide('bat_first_wins * 100', 'bat_first_matches') }} as bat_first_win_pct,

        -- Chase win rate
        {{ safe_divide('chase_wins * 100', 'chase_matches') }}      as chase_win_pct,

        -- Season rank by wins
        rank() over (partition by season order by wins desc)        as season_wins_rank,

        -- NRR proxy (simplified: can't compute without ball-by-ball timing)
        -- In production this would use the actual NRR formula
        round(
            {{ safe_divide('wins * 100', 'matches_played') }} - 50, 2
        )                                                           as nrr_proxy

    from aggregated

)

select * from with_derived
