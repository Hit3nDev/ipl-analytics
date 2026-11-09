# Looker Studio Setup Guide

> Connect your BigQuery marts to a free, shareable dashboard in ~20 minutes.

---

## Prerequisites

- All dbt models run successfully (`dbt run && dbt test` passed)
- A Google account (same one used for BigQuery)
- BigQuery marts available at `YOUR_PROJECT.ipl_marts.*`

---

## Step 1: Open Looker Studio

1. Go to **[lookerstudio.google.com](https://lookerstudio.google.com)**
2. Click **"Blank Report"** or **"Start with a template"**
3. Sign in with your Google account

---

## Step 2: Add BigQuery Data Sources

You'll add **one data source per mart table**. Each becomes a reusable data source across pages.

### 2a. Add `mart_batsman_season_stats`

1. Click **"Add data"** → **"BigQuery"**
2. Select **"My Projects"** → your project → `ipl_marts` → `mart_batsman_season_stats`
3. Click **"Add"**
4. Rename to `Batting Stats` in the data source panel

Repeat for each mart:

| Data Source Name | Dataset | Table |
|------------------|---------|-------|
| `Batting Stats` | `ipl_marts` | `mart_batsman_season_stats` |
| `Bowling Stats` | `ipl_marts` | `mart_bowler_season_stats` |
| `Team Performance` | `ipl_marts` | `mart_team_season_performance` |
| `Head to Head` | `ipl_marts` | `mart_head_to_head` |
| `Venue Analysis` | `ipl_marts` | `mart_venue_analytics` |
| `Powerplay` | `ipl_marts` | `mart_powerplay_analysis` |

---

## Step 3: Create Dashboard Pages

### Page 1 — Season Overview

**Charts to add:**

#### Scorecards (top row)
- Total matches played → `COUNT(match_id)` from Team Performance
- Highest team score ever → `MAX(avg_first_innings_score)` from Venue Analysis
- Most wins in a season → `MAX(wins)` from Team Performance

#### Bar Chart — Wins by Team (current season)
- Dimension: `team`
- Metric: `wins`
- Filter: `season` = [Season filter control]
- Sort: `wins` descending

#### Line Chart — Win % Over Seasons
- Dimension: `season`
- Breakdown: `team`
- Metric: `win_pct`
- Filter: select top 4 teams only (add a filter control)

#### Table — Full League Table
- Dimensions: `team`, `season`
- Metrics: `matches_played`, `wins`, `losses`, `win_pct`, `bat_first_win_pct`, `chase_win_pct`
- Add conditional formatting on `win_pct` (green gradient)

**Filter controls:**
- `season` → Dropdown list → from `mart_team_season_performance.season`

---

### Page 2 — Top Batsmen

#### Bar Chart — Top 10 Run Scorers
- Dimension: `player_name`
- Metric: `runs_scored`
- Filter: `season` = [control], `qualifies_for_rates` = true
- Show top 10

#### Scatter Chart — Strike Rate vs Average
- X-axis: `batting_average`
- Y-axis: `strike_rate`
- Size: `runs_scored`
- Colour dimension: `team`
- Filter: `qualifies_for_rates` = true
- Tooltip: `player_name`, `hundreds`, `fifties`

#### Table — Full Batting Leaderboard
- Dimensions: `player_name`, `team`
- Metrics: `matches`, `innings`, `runs_scored`, `batting_average`, `strike_rate`, `hundreds`, `fifties`, `fours`, `sixes`
- Sort: `runs_scored` descending
- Add conditional formatting

**Filter controls:** `season`, `team` (multi-select)

---

### Page 3 — Bowling Leaders

#### Bar Chart — Top Wicket Takers
- Dimension: `player_name`
- Metric: `wickets`
- Filter: `season`, `qualifies_for_rates` = true

#### Scatter Chart — Economy vs Strike Rate
- X-axis: `economy_rate`
- Y-axis: `bowling_strike_rate`
- Colour: `team`
- Filter: `qualifies_for_rates` = true, lower is better on both axes

#### Table — Bowling Leaderboard
- Metrics: `wickets`, `economy_rate`, `bowling_average`, `bowling_strike_rate`, `dot_ball_pct`, `five_wicket_hauls`

---

### Page 4 — Venue Analysis

#### Geo Map (or Bar Chart if geo not available)
- Dimension: `city`
- Metric: `avg_first_innings_score`
- Size: `total_matches`

> **Tip:** Looker Studio's Geo Chart needs a proper geo dimension. Set `city` type to "City" in data source settings.

#### Treemap — Venues by Matches Hosted
- Dimension: `venue`
- Metric: `total_matches`
- Colour metric: `avg_first_innings_score`

#### Table — Venue Conditions
- Dimensions: `venue`, `city`, `pitch_character`, `venue_type`
- Metrics: `total_matches`, `avg_first_innings_score`, `chase_success_pct`, `dot_ball_pct`, `boundary_4_pct`, `boundary_6_pct`

---

### Page 5 — Head-to-Head

#### Table — All Rivalries
- Dimensions: `team_a`, `team_b`, `dominant_team`
- Metrics: `total_matches`, `team_a_wins`, `team_b_wins`, `team_a_win_pct`
- Filter: `total_matches` >= 10 (meaningful rivalries)

#### Scorecard — Search by team pair
- Add two filter controls for `team_a` and `team_b`
- Scorecards: `team_a_wins`, `team_b_wins`, `total_matches`, `last_match_date`

---

## Step 4: Apply Theme & Branding

1. Click **Theme and Layout** → choose dark theme (looks great for sports)
2. Primary colour: `#1a237e` (deep blue — IPL colours)
3. Accent colour: `#f9a825` (gold)
4. Font: Roboto or Google Sans

---

## Step 5: Add Season Filter to All Pages

1. Create a filter control on Page 1: **Season** (slider or dropdown)
2. Right-click → **"Make filter apply to all pages"**
3. Data source: `mart_team_season_performance.season`

---

## Step 6: Share Your Dashboard

1. Click **Share** → **"Manage access"**
2. Change to **"Anyone with the link can view"**
3. Copy the link → add it to your GitHub README as the **Live Dashboard** link

---

## Tips for Recruiters Viewing Your Dashboard

Add a text box on Page 1 explaining:

```
Built with: Python | dbt Core | BigQuery | Looker Studio
Data: IPL 2008–2024 (250k+ deliveries)
Pipeline: Kaggle → BigQuery RAW → dbt staging/intermediate/marts → Looker Studio
Source code: github.com/Hit3nDev/ipl-analytics
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Permission denied" on BigQuery | Add Looker Studio service account as BigQuery Data Viewer on your project |
| Slow dashboard loads | Check your mart tables have correct partition/cluster — Looker Studio should push filters down |
| Missing data | Re-run `dbt run --full-refresh` |
| Null values in rate stats | Correct — `qualifies_for_rates = false` players don't have enough data |
