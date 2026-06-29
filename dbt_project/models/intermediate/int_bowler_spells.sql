-- models/intermediate/int_bowler_spells.sql
--
-- Aggregates deliveries to one row per (match, inning, bowler).
-- Atomic unit for all bowling statistics.

with

deliveries as (

    select * from {{ ref('stg_deliveries') }}
    where not is_super_over

),

matches as (

    select match_id, season, match_date, venue, city
    from {{ ref('stg_matches') }}

),

bowling_spells as (

    select
        d.match_id,
        d.inning,
        d.bowler                                        as player_name,
        d.bowling_team                                  as team,
        d.batting_team                                  as opposition,
        m.season,
        m.match_date,
        m.venue,
        m.city,

        -- Overs breakdown
        count(distinct d.over_number)                   as overs_bowled,
        sum(case when d.is_legal_ball then 1 else 0 end) as balls_bowled,

        -- Runs conceded (legal balls only — extras count too except byes/legbyes)
        sum(d.total_runs - d.bye_runs - d.legbye_runs)  as runs_conceded,

        -- Wickets (caught/bowled/etc. — not run outs)
        sum(case
            when d.is_wicket
             and d.dismissal_kind not in ('run out', 'retired hurt', 'obstructing the field')
            then 1 else 0
        end)                                            as wickets,

        -- Dot balls & boundaries conceded
        sum(case when d.is_dot_ball then 1 else 0 end)  as dot_balls,
        sum(case when d.is_boundary_4 then 1 else 0 end) as fours_conceded,
        sum(case when d.is_boundary_6 then 1 else 0 end) as sixes_conceded,

        -- Phase breakdown
        sum(case when d.phase = 'powerplay' and d.is_legal_ball then 1 else 0 end) as pp_balls,
        sum(case when d.phase = 'powerplay'
                 then d.total_runs - d.bye_runs - d.legbye_runs else 0 end)         as pp_runs,
        sum(case when d.phase = 'powerplay' and d.is_wicket
                 and d.dismissal_kind not in ('run out', 'retired hurt') then 1 else 0 end) as pp_wickets,

        sum(case when d.phase = 'death' and d.is_legal_ball then 1 else 0 end)     as death_balls,
        sum(case when d.phase = 'death'
                 then d.total_runs - d.bye_runs - d.legbye_runs else 0 end)         as death_runs,
        sum(case when d.phase = 'death' and d.is_wicket
                 and d.dismissal_kind not in ('run out', 'retired hurt') then 1 else 0 end) as death_wickets

    from deliveries d
    inner join matches m using (match_id)

    group by 1, 2, 3, 4, 5, 6, 7, 8, 9

),

derived as (

    select
        *,

        -- Economy rate: runs per over
        {{ economy_rate('runs_conceded', 'balls_bowled') }}         as economy_rate,

        -- Strike rate: balls per wicket
        {{ safe_divide('balls_bowled', 'wickets') }}                as bowling_strike_rate,

        -- Average: runs per wicket
        {{ safe_divide('runs_conceded', 'wickets') }}               as bowling_average,

        -- Dot ball percentage
        {{ safe_divide('dot_balls * 100', 'balls_bowled') }}        as dot_ball_pct,

        -- "Maiden over" approximation: over where 0 runs from legal balls
        -- (Not perfectly calculable at spell level without ball-level grouping)
        0                                                           as maiden_overs   -- placeholder

    from bowling_spells

)

select * from derived
