-- models/marts/mart_head_to_head.sql
--
-- All-time head-to-head records between every pair of teams.
-- Powers the H2H comparison widget in Looker Studio.

{{
  config(
    materialized = 'table',
    cluster_by = ["team_a", "team_b"],
    labels = {"layer": "mart", "domain": "head_to_head"}
  )
}}

with

match_results as (

    select * from {{ ref('int_match_results') }}

),

-- Create canonical (alphabetically ordered) team pairs so
-- (Mumbai Indians, CSK) and (CSK, Mumbai Indians) map to one row
canonical_pairs as (

    select
        case when team1 < team2 then team1 else team2 end   as team_a,
        case when team1 < team2 then team2 else team1 end   as team_b,
        match_id,
        season,
        match_date,
        venue,
        winner,
        result_margin,
        result_by,
        team1,
        team2

    from match_results

),

aggregated as (

    select
        team_a,
        team_b,

        count(*)                                                as total_matches,
        count(distinct season)                                  as seasons,

        -- Wins for each team
        sum(case when winner = team_a then 1 else 0 end)       as team_a_wins,
        sum(case when winner = team_b then 1 else 0 end)       as team_b_wins,

        -- Most recent match
        max(match_date)                                         as last_match_date,
        max(season)                                             as last_season,

        -- Last winner
        max(case when match_date = max(match_date) over (partition by team_a, team_b)
                 then winner else null end)                     as last_match_winner,

        -- Biggest win margin (by runs)
        max(case when result_by = 'runs' then result_margin else 0 end) as biggest_win_by_runs,
        max(case when result_by = 'wickets' then result_margin else 0 end) as biggest_win_by_wickets

    from canonical_pairs

    group by 1, 2

)

select
    *,

    -- Dominance
    case
        when team_a_wins > team_b_wins then team_a
        when team_b_wins > team_a_wins then team_b
        else 'level'
    end                                                         as dominant_team,

    {{ safe_divide('team_a_wins * 100', 'total_matches') }}     as team_a_win_pct,
    {{ safe_divide('team_b_wins * 100', 'total_matches') }}     as team_b_win_pct,

    abs(team_a_wins - team_b_wins)                              as win_difference

from aggregated

where total_matches >= 3    -- Only meaningful rivalries
