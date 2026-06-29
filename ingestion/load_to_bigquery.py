"""
ingestion/load_to_bigquery.py

Downloads the IPL dataset from Kaggle and loads it into BigQuery raw layer.
Handles schema creation, incremental loads, and basic validation.

Usage:
    python ingestion/load_to_bigquery.py --project my-gcp-project
    python ingestion/load_to_bigquery.py --project my-gcp-project --full-refresh
"""

import argparse
import logging
import os
import zipfile
from pathlib import Path

import pandas as pd
from google.cloud import bigquery
from google.cloud.exceptions import NotFound

from ingestion.schema import DELIVERIES_SCHEMA, MATCHES_SCHEMA

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ── Constants ──────────────────────────────────────────────────────────────────

KAGGLE_DATASET = "patrickb1912/ipl-complete-dataset-20082020"
RAW_DATASET = "ipl_raw"
DATA_DIR = Path("data/raw")

TABLE_CONFIG = {
    "matches": {
        "file": "matches.csv",
        "schema": MATCHES_SCHEMA,
        "partition_field": "date",
        "clustering_fields": ["season", "team1", "team2"],
    },
    "deliveries": {
        "file": "deliveries.csv",
        "schema": DELIVERIES_SCHEMA,
        "partition_field": None,
        "clustering_fields": ["match_id", "inning"],
    },
}


# ── BigQuery helpers ───────────────────────────────────────────────────────────


def get_bq_client(project: str) -> bigquery.Client:
    """Return authenticated BigQuery client."""
    return bigquery.Client(project=project)


def ensure_dataset(client: bigquery.Client, project: str) -> None:
    """Create the raw dataset if it doesn't exist."""
    dataset_ref = f"{project}.{RAW_DATASET}"
    try:
        client.get_dataset(dataset_ref)
        log.info("Dataset %s already exists.", dataset_ref)
    except NotFound:
        dataset = bigquery.Dataset(dataset_ref)
        dataset.location = "US"
        dataset.description = "Raw IPL data — source of truth, never modified downstream"
        client.create_dataset(dataset)
        log.info("Created dataset %s.", dataset_ref)


def load_dataframe_to_bq(
    client: bigquery.Client,
    df: pd.DataFrame,
    table_id: str,
    schema: list[bigquery.SchemaField],
    partition_field: str | None,
    clustering_fields: list[str],
    full_refresh: bool,
) -> None:
    """Load a DataFrame to BigQuery with write-truncate or write-append logic."""

    write_disposition = (
        bigquery.WriteDisposition.WRITE_TRUNCATE
        if full_refresh
        else bigquery.WriteDisposition.WRITE_APPEND
    )

    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=write_disposition,
        skip_leading_rows=0,  # DataFrame, not CSV
        autodetect=False,
    )

    if partition_field:
        job_config.time_partitioning = bigquery.TimePartitioning(
            type_=bigquery.TimePartitioningType.DAY,
            field=partition_field,
        )

    if clustering_fields:
        job_config.clustering_fields = clustering_fields

    log.info("Loading %d rows → %s (write=%s)", len(df), table_id, write_disposition.name)
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # Wait for completion

    table = client.get_table(table_id)
    log.info("✅  %s: %d rows total in BigQuery", table_id, table.num_rows)


# ── Data download ──────────────────────────────────────────────────────────────


def download_kaggle_data() -> None:
    """Download and extract the Kaggle IPL dataset."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    if (DATA_DIR / "matches.csv").exists() and (DATA_DIR / "deliveries.csv").exists():
        log.info("Data already downloaded — skipping. Use --force-download to re-download.")
        return

    log.info("Downloading IPL dataset from Kaggle: %s", KAGGLE_DATASET)

    try:
        import kaggle  # noqa: F401
    except ImportError:
        raise RuntimeError(
            "kaggle package not found. Run: pip install kaggle\n"
            "Then set KAGGLE_USERNAME and KAGGLE_KEY environment variables.\n"
            "Get your API key at: https://www.kaggle.com/YOUR_USERNAME/account"
        )

    from kaggle.api.kaggle_api_extended import KaggleApiExtended

    api = KaggleApiExtended()
    api.authenticate()
    api.dataset_download_files(KAGGLE_DATASET, path=str(DATA_DIR), unzip=False)

    zip_path = DATA_DIR / f"{KAGGLE_DATASET.split('/')[-1]}.zip"
    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(DATA_DIR)
    zip_path.unlink()

    log.info("Data downloaded and extracted to %s", DATA_DIR)


# ── Data cleaning ──────────────────────────────────────────────────────────────


def clean_matches(df: pd.DataFrame) -> pd.DataFrame:
    """Clean and type-cast the matches DataFrame."""
    df = df.copy()

    # Standardise column names
    df.columns = [c.lower().strip().replace(" ", "_") for c in df.columns]

    # Date parsing
    df["date"] = pd.to_datetime(df["date"], dayfirst=True, errors="coerce")

    # Numeric coercions
    numeric_cols = ["id", "season", "target_runs", "target_overs", "dl_applied"]
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Standardise team names (franchise renames over the years)
    team_name_map = {
        "Delhi Daredevils": "Delhi Capitals",
        "Deccan Chargers": "Sunrisers Hyderabad",
        "Pune Warriors": "Rising Pune Supergiant",
        "Kings XI Punjab": "Punjab Kings",
    }
    for col in ["team1", "team2", "winner", "toss_winner"]:
        if col in df.columns:
            df[col] = df[col].replace(team_name_map)

    # Dedup
    df = df.drop_duplicates(subset=["id"])

    log.info("Matches cleaned: %d rows", len(df))
    return df


def clean_deliveries(df: pd.DataFrame) -> pd.DataFrame:
    """Clean and type-cast the deliveries DataFrame."""
    df = df.copy()

    df.columns = [c.lower().strip().replace(" ", "_") for c in df.columns]

    numeric_cols = [
        "match_id", "inning", "over", "ball",
        "batsman_runs", "extra_runs", "total_runs",
        "is_wicket", "player_dismissed",
    ]
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Boolean
    df["is_wicket"] = df["is_wicket"].fillna(0).astype(bool)

    # Validate: overs should be 0-19 in T20
    before = len(df)
    df = df[df["over"].between(0, 19)]
    log.info("Removed %d rows with invalid over numbers", before - len(df))

    log.info("Deliveries cleaned: %d rows", len(df))
    return df


# ── Validation ─────────────────────────────────────────────────────────────────


def validate_data(matches: pd.DataFrame, deliveries: pd.DataFrame) -> None:
    """Run basic data quality checks before loading."""
    errors = []

    # Matches
    null_winners = matches["winner"].isna().sum()
    if null_winners > matches["result"].eq("tie").sum() + 5:
        errors.append(f"Matches: {null_winners} null winners (expected ~ties only)")

    if matches["date"].isna().sum() > 0:
        errors.append(f"Matches: {matches['date'].isna().sum()} null dates")

    # Deliveries
    if deliveries["total_runs"].lt(0).any():
        errors.append("Deliveries: negative run values found")

    orphaned = ~deliveries["match_id"].isin(matches["id"])
    if orphaned.sum() > 0:
        errors.append(f"Deliveries: {orphaned.sum()} rows with no matching match_id")

    if errors:
        for e in errors:
            log.warning("⚠️  Validation: %s", e)
    else:
        log.info("✅  All validation checks passed")


# ── Main ───────────────────────────────────────────────────────────────────────


def main(project: str, full_refresh: bool = False, force_download: bool = False) -> None:
    log.info("═" * 60)
    log.info("IPL Analytics — BigQuery Ingestion Pipeline")
    log.info("Project: %s | Full refresh: %s", project, full_refresh)
    log.info("═" * 60)

    # Step 1: Download
    if force_download and (DATA_DIR / "matches.csv").exists():
        (DATA_DIR / "matches.csv").unlink()
        (DATA_DIR / "deliveries.csv").unlink()
    download_kaggle_data()

    # Step 2: Read & clean
    log.info("Reading source files...")
    matches_raw = pd.read_csv(DATA_DIR / "matches.csv", low_memory=False)
    deliveries_raw = pd.read_csv(DATA_DIR / "deliveries.csv", low_memory=False)

    matches = clean_matches(matches_raw)
    deliveries = clean_deliveries(deliveries_raw)

    # Step 3: Validate
    validate_data(matches, deliveries)

    # Step 4: Load to BigQuery
    client = get_bq_client(project)
    ensure_dataset(client, project)

    for table_name, config in TABLE_CONFIG.items():
        df = matches if table_name == "matches" else deliveries
        table_id = f"{project}.{RAW_DATASET}.{table_name}"

        load_dataframe_to_bq(
            client=client,
            df=df,
            table_id=table_id,
            schema=config["schema"],
            partition_field=config["partition_field"],
            clustering_fields=config["clustering_fields"],
            full_refresh=full_refresh,
        )

    log.info("═" * 60)
    log.info("✅  Ingestion complete! Run: cd dbt_project && dbt run")
    log.info("═" * 60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load IPL data to BigQuery")
    parser.add_argument("--project", required=True, help="GCP project ID")
    parser.add_argument(
        "--full-refresh", action="store_true", help="Truncate tables before loading"
    )
    parser.add_argument(
        "--force-download", action="store_true", help="Re-download data even if present"
    )
    args = parser.parse_args()
    main(args.project, args.full_refresh, args.force_download)
