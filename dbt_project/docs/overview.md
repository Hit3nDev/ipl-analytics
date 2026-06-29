{% docs __overview__ %}

# IPL Analytics — dbt Project

## What is this?

This dbt project transforms raw Indian Premier League (IPL) cricket data (2008–2024)
into analytics-ready tables in BigQuery. It powers a Looker Studio dashboard covering
batting, bowling, team performance, head-to-head records, and venue analysis.

## Layer Structure

| Layer | Materialisation | Purpose |
|-------|----------------|---------|
| **Staging** | View | Rename, cast, deduplicate raw data |
| **Intermediate** | Ephemeral | Business logic, joins, aggregations |
| **Marts** | Partitioned Table | BI-ready, Looker Studio–optimised |

## Key Design Decisions

1. **Ephemeral intermediates** — No extra BQ storage cost. Compiled SQL is inlined into mart queries.
2. **Partition by season** — Mart queries in Looker Studio filter by season, making queries 10–50× cheaper.
3. **Cluster by player/team** — Reduces bytes scanned when filtering on common dimensions.
4. **`var('min_season')`** — Allows dev runs on recent data only (`dbt run --vars '{"min_season": 2022}'`), saving BQ query quota.
5. **Canonical H2H ordering** — `least(team1, team2)` / `greatest(...)` ensures each team pair has exactly one row.

## Running in Development

```bash
# Full run
dbt run

# Staging only (fast, ~2 seconds)
dbt run --select staging

# Single model
dbt run --select mart_batsman_season_stats

# Recent seasons only (saves BQ quota)
dbt run --vars '{"min_season": 2022}'

# Tests
dbt test
dbt test --select staging tag:critical
```

## Data Sources

- **`ipl_raw.matches`** — One row per match, loaded from Kaggle CSV
- **`ipl_raw.deliveries`** — Ball-by-ball data, ~250k rows

{% enddocs %}
