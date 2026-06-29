-- models/marts/mart_bowler_season_stats.sql
--
-- One row per (bowler, season).
-- Primary mart for the "Bowling Leaders" dashboard page.

{{
  config(
    materialized = 'table',
    partition_by = {
      "field": "season",
      "data_type": "int64",
      "range": {"start": 2008, "end": 2025, "interval": 1}
    },
    cluster_by = ["player_name", "team"],
    labels = {"layer": "mart", "domain": "bowling"}
  )
}}

with

spells as (

    select * from {{ ref('int_bowler_spells') }}
    where season >= {{ var('min_season') }}

),

aggregated as (

    select
        player_name,
        team,
        season,

        -- Volume
        count(distinct match_id)                            as matches,
        count(*)                                            as innings_bowled,
        sum(balls_bowled)                                   as balls_bowled,
        sum(overs_bowled)                                   as overs_approximate,    -- may count partial
        sum(runs_conceded)                                  as runs_conceded,
        sum(wickets)                                        as wickets,

        -- Shot types conceded
        sum(fours_conceded)                                 as fours_conceded,
        sum(sixes_conceded)                                 as sixes_conceded,
        sum(dot_balls)                                      as dot_balls,

        -- Milestones
        sum(case when wickets >= 5 then 1 else 0 end)       as five_wicket_hauls,
        sum(case when wickets >= 3 then 1 else 0 end)       as three_plus_wicket_hauls,
        max(wickets)                                        as best_wickets_in_spell,

        -- Best figures (wickets in best spell)
        -- We use the corr subquery pattern to get runs in the best spell
        min(case when wickets = max(wickets) over (partition by player_name, season)
                 then runs_conceded else null end)          as runs_in_best_spell,

        -- Phase performance
        sum(pp_balls)                                       as powerplay_balls,
        sum(pp_runs)                                        as powerplay_runs,
        sum(pp_wickets)                                     as powerplay_wickets,
        sum(death_balls)                                    as death_overs_balls,
        sum(death_runs)                                     as death_overs_runs,
        sum(death_wickets)                                  as death_overs_wickets

    from spells

    group by 1, 2, 3

),

with_rates as (

    select
        *,

        -- Economy rate (runs per over)
        {{ economy_rate('runs_conceded', 'balls_bowled') }}                 as economy_rate,

        -- Bowling average (runs per wicket)
        {{ safe_divide('runs_conceded', 'wickets') }}                       as bowling_average,

        -- Bowling strike rate (balls per wicket)
        {{ safe_divide('balls_bowled', 'wickets') }}                        as bowling_strike_rate,

        -- Phase economy rates
        {{ economy_rate('powerplay_runs', 'powerplay_balls') }}             as powerplay_economy,
        {{ economy_rate('death_overs_runs', 'death_overs_balls') }}         as death_economy,

        -- Dot ball percentage
        {{ safe_divide('dot_balls * 100', 'balls_bowled') }}                as dot_ball_pct,

        -- Boundary percentage of runs conceded
        {{ safe_divide('(fours_conceded * 4 + sixes_conceded * 6) * 100', 'runs_conceded') }} as boundary_pct_conceded,

        -- Season rank
        rank() over (
            partition by season
            order by wickets desc, economy_rate asc
        )                                                                   as season_wickets_rank,

        -- Best figures label
        concat(
            cast(max(wickets) over (partition by player_name, season) as string),
            '/',
            cast(
                min(case when wickets = max(wickets) over (partition by player_name, season)
                         then runs_conceded else null end
                ) over (partition by player_name, season)
            as string)
        )                                                                   as best_figures,

        case
            when balls_bowled >= {{ var('min_balls_bowling') }} then true
            else false
        end                                                                 as qualifies_for_rates

    from aggregated

)

select * from with_rates
