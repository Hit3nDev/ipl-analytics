"""
ingestion/schema.py

BigQuery schema definitions for the IPL raw layer.
Explicit schemas are better than autodetect — they're reproducible and catch issues early.
"""

from google.cloud import bigquery

F = bigquery.SchemaField

MATCHES_SCHEMA = [
    F("id",                 "INTEGER",   "REQUIRED", description="Unique match identifier"),
    F("season",             "INTEGER",   "NULLABLE", description="IPL season year"),
    F("city",               "STRING",    "NULLABLE", description="City where match was played"),
    F("date",               "DATE",      "NULLABLE", description="Match date"),
    F("player_of_match",    "STRING",    "NULLABLE"),
    F("venue",              "STRING",    "NULLABLE"),
    F("neutral_venue",      "INTEGER",   "NULLABLE", description="1 if neutral venue"),
    F("team1",              "STRING",    "NULLABLE"),
    F("team2",              "STRING",    "NULLABLE"),
    F("toss_winner",        "STRING",    "NULLABLE"),
    F("toss_decision",      "STRING",    "NULLABLE", description="bat or field"),
    F("winner",             "STRING",    "NULLABLE"),
    F("result",             "STRING",    "NULLABLE", description="normal / tie / no result"),
    F("result_margin",      "FLOAT64",   "NULLABLE", description="Runs or wickets margin"),
    F("eliminator",         "STRING",    "NULLABLE", description="Y if Super Over"),
    F("method",             "STRING",    "NULLABLE", description="D/L method applied"),
    F("umpire1",            "STRING",    "NULLABLE"),
    F("umpire2",            "STRING",    "NULLABLE"),
]

DELIVERIES_SCHEMA = [
    F("match_id",           "INTEGER",   "REQUIRED"),
    F("inning",             "INTEGER",   "REQUIRED", description="1 or 2"),
    F("batting_team",       "STRING",    "NULLABLE"),
    F("bowling_team",       "STRING",    "NULLABLE"),
    F("over",               "INTEGER",   "REQUIRED", description="0-indexed over number"),
    F("ball",               "INTEGER",   "REQUIRED", description="Ball within the over"),
    F("batsman",            "STRING",    "NULLABLE"),
    F("non_striker",        "STRING",    "NULLABLE"),
    F("bowler",             "STRING",    "NULLABLE"),
    F("is_super_over",      "INTEGER",   "NULLABLE"),
    F("wide_runs",          "INTEGER",   "NULLABLE"),
    F("bye_runs",           "INTEGER",   "NULLABLE"),
    F("legbye_runs",        "INTEGER",   "NULLABLE"),
    F("noball_runs",        "INTEGER",   "NULLABLE"),
    F("penalty_runs",       "INTEGER",   "NULLABLE"),
    F("batsman_runs",       "INTEGER",   "NULLABLE"),
    F("extra_runs",         "INTEGER",   "NULLABLE"),
    F("total_runs",         "INTEGER",   "NULLABLE"),
    F("player_dismissed",   "STRING",    "NULLABLE"),
    F("dismissal_kind",     "STRING",    "NULLABLE"),
    F("fielder",            "STRING",    "NULLABLE"),
    F("is_wicket",          "BOOLEAN",   "NULLABLE"),
]
