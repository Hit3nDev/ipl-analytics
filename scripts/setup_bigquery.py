"""
scripts/setup_bigquery.py

One-time setup script for the BigQuery project.
Creates datasets, sets IAM roles, and validates the connection.

Usage:
    python scripts/setup_bigquery.py --project YOUR_PROJECT_ID
"""

import argparse
import sys

from google.cloud import bigquery
from google.cloud.exceptions import Conflict


DATASETS = {
    "ipl_raw": {
        "description": "Raw IPL data — source of truth, loaded by ingestion scripts",
        "labels": {"layer": "raw", "project": "ipl-analytics"},
    },
    "ipl_staging": {
        "description": "dbt staging views — cleaned and typed raw data",
        "labels": {"layer": "staging", "project": "ipl-analytics"},
    },
    "ipl_marts": {
        "description": "dbt mart tables — BI-ready, partitioned, clustered",
        "labels": {"layer": "mart", "project": "ipl-analytics"},
    },
    "dbt_dev": {
        "description": "Developer sandbox — dbt dev runs target this dataset",
        "labels": {"layer": "dev", "project": "ipl-analytics"},
    },
}


def create_datasets(client: bigquery.Client, project: str) -> None:
    for dataset_id, config in DATASETS.items():
        full_id = f"{project}.{dataset_id}"
        dataset = bigquery.Dataset(full_id)
        dataset.location = "US"
        dataset.description = config["description"]
        dataset.labels = config["labels"]

        try:
            client.create_dataset(dataset, exists_ok=False)
            print(f"✅  Created dataset: {full_id}")
        except Conflict:
            print(f"⏭️  Dataset already exists: {full_id}")


def validate_connection(client: bigquery.Client, project: str) -> None:
    """Run a dummy query to confirm authentication works."""
    query = "SELECT 1 AS connection_test"
    result = client.query(query).result()
    rows = list(result)
    assert rows[0]["connection_test"] == 1
    print(f"✅  Connection to project '{project}' validated")


def print_next_steps(project: str) -> None:
    print("\n" + "═" * 60)
    print("Setup complete! Next steps:")
    print("═" * 60)
    print(f"""
1. Download the dataset:
   python ingestion/load_to_bigquery.py --project {project}

2. Set up dbt:
   cp dbt_project/profiles.yml.example ~/.dbt/profiles.yml
   # Edit ~/.dbt/profiles.yml and set project: {project}

3. Run dbt:
   cd dbt_project
   dbt deps
   dbt run
   dbt test
   dbt docs generate && dbt docs serve

4. Connect Looker Studio:
   See looker_studio/SETUP_GUIDE.md
""")


def main(project: str) -> None:
    print(f"Setting up BigQuery for project: {project}")
    client = bigquery.Client(project=project)

    validate_connection(client, project)
    create_datasets(client, project)
    print_next_steps(project)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True, help="GCP project ID")
    args = parser.parse_args()
    main(args.project)
