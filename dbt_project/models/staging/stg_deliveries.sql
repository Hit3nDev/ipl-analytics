-- models/staging/stg_deliveries.sql
--
-- Cleans the ball-by-ball deliveries table (~250k rows).
-- Key derivations:
--   • legal_ball flag (wide/no-ball don't count toward over)
--   • over_label (human-readable "P1 O3 B2")
--   • phase classification (powerplay / middle / death)
--   • dot_ball, boundary_4, boundary_6 boolean flags for aggregation speed

with

source as (

    select * from {{ source('ipl_raw', 'deliveries') }}

),

renamed as (

    select
        -- Foreign keys
        cast(match_id as int64)                 as match_id,
        cast(inning as int64)                   as inning,

        -- Ball coordinates
        cast(over as int64)                     as over_number,       -- 0-indexed
        cast(ball as int64)                     as ball_number,
        cast(over as int64) + 1                 as over_display,      -- 1-indexed for display

        -- Teams
        batting_team,
        bowling_team,

        -- Players
        batsman,
        non_striker,
        bowler,

        -- Runs
        cast(batsman_runs as int64)             as batsman_runs,
        cast(extra_runs as int64)               as extra_runs,
        cast(total_runs as int64)               as total_runs,
        cast(wide_runs as int64)                as wide_runs,
        cast(bye_runs as int64)                 as bye_runs,
        cast(legbye_runs as int64)              as legbye_runs,
        cast(noball_runs as int64)              as noball_runs,
        cast(penalty_runs as int64)             as penalty_runs,

        -- Wicket
        cast(is_wicket as bool)                 as is_wicket,
        player_dismissed,
        dismissal_kind,
        fielder,

        -- Super Over flag
        cast(coalesce(is_super_over, 0) as bool) as is_super_over

    from source

),

derived as (

    select
        *,

        -- A "legal" ball counts toward the over (no wide, no no-ball)
        case
            when wide_runs > 0 or noball_runs > 0 then false
            else true
        end                                     as is_legal_ball,

        -- Dot ball: legal delivery, batsman scored 0
        case
            when wide_runs = 0 and noball_runs = 0 and batsman_runs = 0 then true
            else false
        end                                     as is_dot_ball,

        -- Boundaries
        case when batsman_runs = 4 then true else false end  as is_boundary_4,
        case when batsman_runs = 6 then true else false end  as is_boundary_6,

        -- Phase (T20 powerplay = overs 1-6, middle = 7-15, death = 16-20)
        case
            when over_number between 0 and 5   then 'powerplay'
            when over_number between 6 and 14  then 'middle'
            when over_number between 15 and 19 then 'death'
        end                                     as phase,

        -- Human-readable label
        concat('Inning ', inning, ' Over ', over_display, ' Ball ', ball_number) as delivery_label,

        -- Audit
        current_timestamp()                     as _loaded_at

    from renamed

)

select * from derived
