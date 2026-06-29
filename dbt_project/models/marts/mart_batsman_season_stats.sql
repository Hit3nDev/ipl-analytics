-- models/marts/mart_batsman_season_stats.sql
--
-- One row per (batsman, season) with full career-in-that-season statistics.
-- Primary mart for the "Top Batsmen" dashboard page.
--
-- Looker Studio fields used:
--   season, player_name, team, matches, innings, runs_scored,
--   strike_rate, batting_average, hundreds, fifties

{{
  config(
    materialized = 'table',
    partition_by = {
      "field": "season",
      "data_type": "int64",
      "range": {"start": 2008, "end": 2025, "interval": 1}
    },
    cluster_by = ["player_name", "team"],
    labels = {"layer": "mart", "domain": "batting"}
  )
}}

with

innings as (

    select * from {{ ref('int_player_innings') }}
    where season >= {{ var('min_season') }}

),

aggregated as (

    select
        player_name,
        team,
        season,

        -- Volume
        count(distinct match_id)                            as matches,
        count(*)                                            as innings,
        sum(runs_scored)                                    as runs_scored,
        sum(balls_faced)                                    as balls_faced,
        sum(fours)                                          as fours,
        sum(sixes)                                          as sixes,
        sum(dot_balls)                                      as dot_balls,

        -- Milestones
        sum(case when runs_scored >= 100 then 1 else 0 end) as hundreds,
        sum(case when runs_scored >= 50
                  and runs_scored < 100 then 1 else 0 end)  as fifties,
        sum(case when runs_scored >= 25
                  and runs_scored < 50 then 1 else 0 end)   as twenty_fives,
        max(runs_scored)                                    as highest_score,

        -- Dismissals
        sum(was_dismissed)                                  as dismissals,
        sum(case when is_not_out then 1 else 0 end)         as not_outs,

        -- Phase performance
        sum(pp_runs)                                        as powerplay_runs,
        sum(pp_balls)                                       as powerplay_balls,
        sum(middle_runs)                                    as middle_runs,
        sum(middle_balls)                                   as middle_balls,
        sum(death_runs)                                     as death_runs,
        sum(death_balls)                                    as death_balls

    from innings

    group by 1, 2, 3

),

with_rates as (

    select
        *,

        -- Overall strike rate
        {{ calculate_strike_rate('runs_scored', 'balls_faced') }}           as strike_rate,

        -- Batting average (runs / dismissals, treating not-outs correctly)
        {{ safe_divide('runs_scored', 'dismissals') }}                      as batting_average,

        -- Phase strike rates
        {{ calculate_strike_rate('powerplay_runs', 'powerplay_balls') }}    as powerplay_strike_rate,
        {{ calculate_strike_rate('middle_runs', 'middle_balls') }}          as middle_strike_rate,
        {{ calculate_strike_rate('death_runs', 'death_balls') }}            as death_strike_rate,

        -- Boundary percentage
        {{ safe_divide('(fours * 4 + sixes * 6) * 100', 'runs_scored') }}  as boundary_pct,

        -- Dot ball percentage
        {{ safe_divide('dot_balls * 100', 'balls_faced') }}                 as dot_ball_pct,

        -- Season rank by runs (useful for Looker Studio ranking charts)
        rank() over (
            partition by season
            order by runs_scored desc
        )                                                                   as season_runs_rank

    from aggregated

),

-- Apply qualifying threshold for rate stats
qualified as (

    select
        *,
        case
            when balls_faced >= {{ var('min_balls_batting') }} then true
            else false
        end                                                                 as qualifies_for_rates

    from with_rates

)

select * from qualified
