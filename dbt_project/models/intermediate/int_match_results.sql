-- models/intermediate/int_match_results.sql
--
-- Enriches stg_matches with first-innings score from deliveries,
-- toss advantage analysis, and chase success flags.
-- Used by mart_team_season_performance and mart_head_to_head.

with

matches as (

    select * from {{ ref('stg_matches') }}
    where result_type = 'normal'    -- Exclude ties and no results

),

-- Aggregate first and second innings totals from deliveries
innings_totals as (

    select
        match_id,
        inning,
        batting_team,
        bowling_team,
        sum(total_runs)                                 as total_runs,
        sum(case when is_wicket then 1 else 0 end)      as wickets_lost,
        count(distinct over_number)                     as overs_completed

    from {{ ref('stg_deliveries') }}
    where inning in (1, 2)
      and not is_super_over

    group by 1, 2, 3, 4

),

first_innings as (
    select
        match_id,
        batting_team    as first_innings_team,
        total_runs      as first_innings_score,
        wickets_lost    as first_innings_wickets

    from innings_totals
    where inning = 1
),

second_innings as (
    select
        match_id,
        batting_team    as second_innings_team,
        total_runs      as second_innings_score,
        wickets_lost    as second_innings_wickets

    from innings_totals
    where inning = 2
),

joined as (

    select
        m.match_id,
        m.season,
        m.season_era,
        m.match_date,
        m.venue,
        m.city,
        m.team1,
        m.team2,
        m.winner,
        m.result_margin,
        m.result_by,
        m.toss_winner,
        m.toss_decision,
        m.toss_winner_won_match,
        m.player_of_match,
        m.is_neutral_venue,

        fi.first_innings_team,
        fi.first_innings_score,
        fi.first_innings_wickets,
        si.second_innings_team,
        si.second_innings_score,
        si.second_innings_wickets,

        -- Chase analysis
        case
            when si.second_innings_team = m.winner then true
            else false
        end                                             as chase_successful,

        -- Chase difficulty
        case
            when fi.first_innings_score >= 200 then 'very_high_target'
            when fi.first_innings_score >= 170 then 'high_target'
            when fi.first_innings_score >= 150 then 'moderate_target'
            else 'low_target'
        end                                             as target_tier,

        -- Team that lost
        case
            when m.winner = m.team1 then m.team2
            when m.winner = m.team2 then m.team1
            else null
        end                                             as loser

    from matches m
    left join first_innings fi  using (match_id)
    left join second_innings si using (match_id)

)

select * from joined
