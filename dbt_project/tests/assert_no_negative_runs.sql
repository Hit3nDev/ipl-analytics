-- tests/assert_no_negative_runs.sql
--
-- Singular test: ensures no delivery has a negative total_runs value.
-- A non-empty result set means the test FAILS.

select
    match_id,
    inning,
    over_number,
    ball_number,
    total_runs
from {{ ref('stg_deliveries') }}
where total_runs < 0
