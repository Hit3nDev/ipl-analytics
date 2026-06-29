-- models/marts/mart_venue_analytics.sql
--
-- One row per venue with batting vs. bowling conditions analysis.
-- Drives the "Venue Heatmap" page in Looker Studio.

{{
  config(
    materialized = 'table',
    cluster_by = ["venue"],
    labels = {"layer": "mart", "domain": "venue"}
  )
}}

with

match_results as (

    select
        match_id,
        season,
        venue,
        city,
        first_innings_score,
        second_innings_score,
        chase_successful,
        toss_decision
    from {{ ref('int_match_results') }}

),

deliveries as (

    select
        d.match_id,
        d.batsman_runs,
        d.is_wicket,
        d.is_boundary_4,
        d.is_boundary_6,
        d.is_dot_ball,
        d.phase
    from {{ ref('stg_deliveries') }} d
    where not d.is_super_over

),

deliveries_with_venue as (

    select
        d.*,
        m.venue,
        m.city,
        m.season
    from deliveries d
    inner join match_results m using (match_id)

),

venue_stats as (

    select
        venue,
        city,

        -- Volume
        count(distinct match_id)                            as total_matches,
        count(distinct season)                              as seasons_hosted,

        -- Scoring environment
        avg(batsman_runs)                                   as avg_runs_per_ball,
        sum(case when is_boundary_4 then 1 else 0 end) * 100.0
            / count(*)                                      as boundary_4_pct,
        sum(case when is_boundary_6 then 1 else 0 end) * 100.0
            / count(*)                                      as boundary_6_pct,
        sum(case when is_dot_ball then 1 else 0 end) * 100.0
            / count(*)                                      as dot_ball_pct,
        sum(case when is_wicket then 1 else 0 end) * 6.0
            / nullif(count(*), 0)                           as wickets_per_over,

        -- Phase scoring rates (runs per ball × 6 = runs per over)
        avg(case when phase = 'powerplay' then batsman_runs else null end) * 6
                                                            as pp_runs_per_over,
        avg(case when phase = 'middle' then batsman_runs else null end) * 6
                                                            as middle_runs_per_over,
        avg(case when phase = 'death' then batsman_runs else null end) * 6
                                                            as death_runs_per_over

    from deliveries_with_venue
    group by 1, 2

),

venue_match_stats as (

    select
        venue,
        avg(first_innings_score)                            as avg_first_innings_score,
        avg(second_innings_score)                           as avg_second_innings_score,
        sum(case when chase_successful then 1 else 0 end) * 100.0
            / count(*)                                      as chase_success_pct,
        sum(case when toss_decision = 'bat' then 1 else 0 end) * 100.0
            / count(*)                                      as toss_bat_first_pct

    from match_results
    group by 1

),

joined as (

    select
        vs.*,
        vms.avg_first_innings_score,
        vms.avg_second_innings_score,
        vms.chase_success_pct,
        vms.toss_bat_first_pct,

        -- Venue classification
        case
            when vs.avg_runs_per_ball * 6 >= 9.0  then 'high_scoring'
            when vs.avg_runs_per_ball * 6 >= 7.5  then 'moderate_scoring'
            else 'low_scoring'
        end                                                 as venue_type,

        case
            when vs.wickets_per_over >= 1.5 then 'bowler_friendly'
            when vs.wickets_per_over >= 1.1 then 'balanced'
            else 'batter_friendly'
        end                                                 as pitch_character

    from venue_stats vs
    left join venue_match_stats vms using (venue)

    where vs.total_matches >= 5  -- Only venues with meaningful sample

)

select * from joined
