-- models/intermediate/int_player_innings.sql
--
-- Aggregates deliveries to one row per (match, inning, batsman).
-- This is the atomic unit for all batting statistics.
-- Materialised as ephemeral — compiled inline into marts, zero BQ table cost.

with

deliveries as (

    select * from {{ ref('stg_deliveries') }}
    where not is_super_over      -- Exclude super overs from career stats

),

matches as (

    select
        match_id,
        season,
        match_date,
        venue,
        city
    from {{ ref('stg_matches') }}

),

batting_innings as (

    select
        d.match_id,
        d.inning,
        d.batsman                                       as player_name,
        d.batting_team                                  as team,
        d.bowling_team                                  as opposition,
        m.season,
        m.match_date,
        m.venue,
        m.city,

        -- Runs
        sum(d.batsman_runs)                             as runs_scored,
        sum(case when d.is_legal_ball then 1 else 0 end) as balls_faced,

        -- Shot types
        sum(case when d.is_boundary_4 then 1 else 0 end) as fours,
        sum(case when d.is_boundary_6 then 1 else 0 end) as sixes,
        sum(case when d.is_dot_ball then 1 else 0 end)   as dot_balls,

        -- Phase breakdown
        sum(case when d.phase = 'powerplay' and d.is_legal_ball then 1 else 0 end) as pp_balls,
        sum(case when d.phase = 'powerplay' then d.batsman_runs else 0 end)         as pp_runs,
        sum(case when d.phase = 'middle' and d.is_legal_ball then 1 else 0 end)     as middle_balls,
        sum(case when d.phase = 'middle' then d.batsman_runs else 0 end)            as middle_runs,
        sum(case when d.phase = 'death' and d.is_legal_ball then 1 else 0 end)      as death_balls,
        sum(case when d.phase = 'death' then d.batsman_runs else 0 end)             as death_runs,

        -- Dismissal
        max(case when d.is_wicket and d.player_dismissed = d.batsman then 1 else 0 end) as was_dismissed,
        max(case when d.is_wicket and d.player_dismissed = d.batsman
                 then d.dismissal_kind else null end)                               as dismissal_kind,

        -- Milestone flags (set after aggregation in derived CTE)
        max(d.batsman_runs)                             as max_single_ball_runs

    from deliveries d
    inner join matches m using (match_id)

    group by 1, 2, 3, 4, 5, 6, 7, 8, 9

),

derived as (

    select
        *,

        -- Strike rate: runs per 100 legal balls
        {{ calculate_strike_rate('runs_scored', 'balls_faced') }}   as strike_rate,

        -- Boundary percentage of runs
        {{ safe_divide('(fours * 4 + sixes * 6) * 100', 'runs_scored') }} as boundary_pct,

        -- Innings milestone
        case
            when runs_scored >= 100 then '100+'
            when runs_scored >= 50  then '50-99'
            when runs_scored >= 25  then '25-49'
            else 'under_25'
        end                                             as innings_tier,

        -- "Not out" flag
        case when was_dismissed = 0 then true else false end as is_not_out

    from batting_innings

)

select * from derived
