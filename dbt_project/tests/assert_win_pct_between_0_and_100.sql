-- tests/assert_win_pct_between_0_and_100.sql
--
-- Ensure no team has a win percentage outside [0, 100].

select
    team,
    season,
    win_pct
from {{ ref('mart_team_season_performance') }}
where win_pct < 0 or win_pct > 100
