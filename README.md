# 🏏 IPL Analytics Pipeline
### End-to-End Data Engineering with dbt · BigQuery · Looker Studio

![Pipeline Architecture](docs/architecture.png)

[![dbt](https://img.shields.io/badge/dbt-1.8-orange?logo=dbt)](https://www.getdbt.com/)
[![BigQuery](https://img.shields.io/badge/BigQuery-Free_Tier-blue?logo=google-cloud)](https://cloud.google.com/bigquery)
[![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python)](https://python.org)
[![CI](https://github.com/Hit3nDev/ipl-analytics/actions/workflows/dbt_ci.yml/badge.svg)](https://github.com/Hit3nDev/ipl-analytics/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🔍 What This Project Does

Ingests **16 years of Indian Premier League (IPL) cricket data** (2008–2024, ~250k ball-by-ball deliveries) from a public dataset, transforms it through a multi-layer **dbt pipeline**, loads it into **Google BigQuery**, and visualises it in **Looker Studio** — all on the **free tier**.

**Live Dashboard → [View on Looker Studio](https://lookerstudio.google.com/YOUR_LINK_HERE)**

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA SOURCES                             │
│   Kaggle IPL Dataset (CSV)  ·  GitHub raw files (seeds)        │
└─────────────────┬───────────────────────────────────────────────┘
                  │ ingestion/load_to_bigquery.py
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   BigQuery RAW layer                            │
│         ipl_raw.deliveries  ·  ipl_raw.matches                  │
└─────────────────┬───────────────────────────────────────────────┘
                  │ dbt run --select staging
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  dbt STAGING layer                              │
│      stg_matches  ·  stg_deliveries  ·  stg_teams              │
│      • Rename columns to snake_case                             │
│      • Cast data types                                          │
│      • Null handling & deduplication                            │
└─────────────────┬───────────────────────────────────────────────┘
                  │ dbt run --select intermediate
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                dbt INTERMEDIATE layer                           │
│   int_match_results  ·  int_player_innings  ·  int_team_stats  │
│      • Business logic aggregations                              │
│      • Join enrichment                                          │
└─────────────────┬───────────────────────────────────────────────┘
                  │ dbt run --select marts
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    dbt MART layer                               │
│  mart_batsman_season_stats  ·  mart_bowler_season_stats         │
│  mart_team_season_performance  ·  mart_head_to_head             │
│  mart_venue_analytics  ·  mart_powerplay_analysis               │
│      • Business-ready, denormalised tables                      │
│      • Optimised for BI tools                                   │
└─────────────────┬───────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Looker Studio                                 │
│   Season Overview  ·  Top Batsmen  ·  Bowling Leaders           │
│   Venue Heatmaps  ·  Head-to-Head  ·  Win Probability          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Dashboard Previews

| Season Overview | Batsman Stats | Venue Analysis |
|:-:|:-:|:-:|
| ![](docs/screenshots/season_overview.png) | ![](docs/screenshots/batsman.png) | ![](docs/screenshots/venue.png) |

---

## 🛠️ Tech Stack

| Tool | Role | Cost |
|------|------|------|
| **Python 3.11** | Data ingestion, transformation | Free |
| **Google BigQuery** | Cloud data warehouse | Free (10GB storage, 1TB/mo queries) |
| **dbt Core 1.8** | Data transformation & documentation | Free (open source) |
| **Looker Studio** | Dashboards & visualisation | Free |
| **GitHub Actions** | CI — dbt test on every PR | Free (2000 min/mo) |
| **Kaggle API** | Source dataset download | Free |

---

## 🚀 Quick Start

### Prerequisites
- Python 3.9+
- A Google Cloud account (free tier — no card needed for $300 trial, or use sandbox)
- A Kaggle account

### 1. Clone & Install
```bash
git clone https://github.com/Hit3nDev/ipl-analytics.git
cd ipl-analytics
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Google Cloud Setup (one-time, ~10 minutes)
```bash
# Install gcloud CLI: https://cloud.google.com/sdk/docs/install
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# Create BigQuery datasets
python scripts/setup_bigquery.py --project YOUR_PROJECT_ID
```

### 3. Download & Ingest Data
```bash
# Set your Kaggle credentials
export KAGGLE_USERNAME=your_username
export KAGGLE_KEY=your_api_key

# Download IPL dataset and load to BigQuery
python ingestion/load_to_bigquery.py --project YOUR_PROJECT_ID
```

### 4. Run dbt Transformations
```bash
cd dbt_project

# Install dbt packages
dbt deps

# Test connection
dbt debug

# Run all models (staging → intermediate → marts)
dbt run

# Run tests
dbt test

# Generate & serve documentation
dbt docs generate
dbt docs serve  # Opens browser at localhost:8080
```

### 5. Connect Looker Studio
See [`looker_studio/SETUP_GUIDE.md`](looker_studio/SETUP_GUIDE.md) for the step-by-step dashboard setup.

---

## 📁 Project Structure

```
ipl-analytics/
├── .github/
│   └── workflows/
│       └── dbt_ci.yml              # CI: lint + test on every PR
├── ingestion/
│   ├── load_to_bigquery.py         # Downloads Kaggle data → BigQuery
│   └── schema.py                   # BigQuery schema definitions
├── dbt_project/
│   ├── dbt_project.yml             # dbt config
│   ├── profiles.yml.example        # BigQuery connection template
│   ├── packages.yml                # dbt_utils, dbt_expectations
│   ├── models/
│   │   ├── staging/                # Raw → cleaned
│   │   │   ├── stg_matches.sql
│   │   │   ├── stg_deliveries.sql
│   │   │   └── _staging.yml        # Column tests & docs
│   │   ├── intermediate/           # Business logic joins
│   │   │   ├── int_match_results.sql
│   │   │   ├── int_player_innings.sql
│   │   │   └── int_team_stats.sql
│   │   └── marts/                  # BI-ready tables
│   │       ├── mart_batsman_season_stats.sql
│   │       ├── mart_bowler_season_stats.sql
│   │       ├── mart_team_season_performance.sql
│   │       ├── mart_head_to_head.sql
│   │       ├── mart_venue_analytics.sql
│   │       ├── mart_powerplay_analysis.sql
│   │       └── _marts.yml
│   ├── tests/
│   │   └── assert_no_negative_runs.sql
│   ├── macros/
│   │   ├── calculate_strike_rate.sql
│   │   └── economy_rate.sql
│   └── docs/
│       └── overview.md
├── looker_studio/
│   ├── SETUP_GUIDE.md              # Step-by-step Looker Studio setup
│   └── dashboard_template.json     # Looker Studio template export
├── scripts/
│   └── setup_bigquery.py           # One-time GCP setup
├── docs/
│   └── architecture.png
├── requirements.txt
├── .env.example
├── .gitignore
└── README.md
```

---

## 🧪 Data Quality & Testing

dbt tests run on every model:

```yaml
# Examples from _staging.yml
- not_null
- unique
- accepted_values
- dbt_expectations.expect_column_values_to_be_between
- relationships (referential integrity)
```

Run tests locally:
```bash
dbt test                          # All tests
dbt test --select staging         # Staging layer only
dbt test --select tag:critical    # Critical tests only
```

---

## 📈 Key Metrics & Insights

The marts answer questions like:
- 🏏 **Who are the all-time top run-scorers by season?** → `mart_batsman_season_stats`
- 🎳 **Which bowler has the best economy in powerplay overs?** → `mart_powerplay_analysis`
- 🏟️ **Which venues favour batsmen vs bowlers?** → `mart_venue_analytics`
- ⚔️ **Head-to-head record between any two teams?** → `mart_head_to_head`
- 📊 **Season-by-season team win percentages?** → `mart_team_season_performance`

---

## 🤝 Contributing

Pull requests welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

1. Fork the repo
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Run `dbt test` and ensure all pass
4. Open a PR — CI will run automatically

---

## 📄 License

MIT — see [LICENSE](LICENSE)

---

*Built to demonstrate production dbt + BigQuery skills. Dataset: [IPL Complete Dataset (2008-2024)](https://www.kaggle.com/datasets/patrickb1912/ipl-complete-dataset-20082020) on Kaggle — CC0 Public Domain.*
