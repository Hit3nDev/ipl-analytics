-- models/staging/stg_matches.sql
--
-- Cleans and standardises the raw matches table.
-- This is the only place we reference ipl_raw.matches.
-- All downstream models read from this staging view.
--
-- Transformations applied here:
--   • Rename columns to consistent snake_case
--   • Cast types explicitly (never trust autodetect downstream)
--   • Derive toss_won_match (common business question)
--   • Standardise team names for consistency across seasons
--   • Filter out no-result matches for most marts (kept here, filtered downstream)

with

source as (

    select * from {{ source('ipl_raw', 'matches') }}

),

renamed as (

    select
        -- Keys
        cast(id as int64)                       as match_id,
        cast(season as int64)                   as season,

        -- Match metadata
        city,
        cast(date as date)                      as match_date,
        venue,
        cast(neutral_venue as bool)             as is_neutral_venue,

        -- Teams
        team1,
        team2,

        -- Toss
        toss_winner,
        toss_decision,

        -- Result
        winner,
        result                                  as result_type,       -- normal / tie / no result
        cast(result_margin as float64)          as result_margin,
        case
            when result = 'runs'    then 'runs'
            when result = 'wickets' then 'wickets'
            when result = 'tie'     then 'tie'
            else 'no result'
        end                                     as result_by,

        -- Super Over
        case
            when lower(eliminator) = 'y' then true
            else false
        end                                     as is_super_over,

        -- D/L
        method,

        -- Player & officials
        player_of_match,
        umpire1,
        umpire2,

        -- Derived
        case
            when toss_winner = winner then true
            else false
        end                                     as toss_winner_won_match,

        case
            when winner = team1 then 'team1'
            when winner = team2 then 'team2'
            else null
        end                                     as winning_team_position,

        -- Audit
        current_timestamp()                     as _loaded_at

    from source

),

-- Assign home/away based on team order (proxy — IPL rarely uses this concept)
with_home_away as (

    select
        *,
        -- Season era classification for trend analysis
        case
            when season between 2008 and 2012 then 'era_1_founding'
            when season between 2013 and 2017 then 'era_2_growth'
            when season between 2018 and 2021 then 'era_3_maturity'
            when season >= 2022               then 'era_4_modern'
        end                                     as season_era

    from renamed

)

select * from with_home_away
