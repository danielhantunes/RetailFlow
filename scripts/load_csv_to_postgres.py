#!/usr/bin/env python3
"""
Load Olist CSV files into Azure PostgreSQL using COPY for high performance.
Expects POSTGRES_HOST, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD from env
(populated from Terraform outputs in CI).
Creates database 'retailflow' if missing, runs create_tables.sql, then COPY each CSV.
Table names: olist_*_dataset.csv -> strip "olist_" and "_dataset" (e.g. orders, geolocation).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

try:
    import psycopg2
    from psycopg2 import sql
except ImportError:
    print("psycopg2 is required. Install with: pip install psycopg2-binary", file=sys.stderr)
    sys.exit(1)


def get_connection(dbname: str):
    return psycopg2.connect(
        host=os.environ["POSTGRES_HOST"],
        dbname=dbname,
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        connect_timeout=60,
    )


def ensure_database(conn):
    """Create retailflow database if it does not exist."""
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", ("retailflow",))
    if cur.fetchone() is None:
        cur.execute("CREATE DATABASE retailflow")
        print("Created database retailflow")
    cur.close()
    conn.close()


def csv_filename_to_table(filename: str) -> str | None:
    """Convert olist_*_dataset.csv to table name: remove olist_ prefix and _dataset suffix."""
    name = Path(filename).stem
    if name.startswith("olist_") and name.endswith("_dataset"):
        return name[6:-8]  # len("olist_")=6, len("_dataset")=8
    return None


def main():
    for var in ("POSTGRES_HOST", "POSTGRES_USER", "POSTGRES_PASSWORD"):
        if not os.environ.get(var):
            print(f"Missing environment variable: {var}", file=sys.stderr)
            sys.exit(1)
    dataset_dir = os.environ.get("DATASET_DIR", "dataset")
    sql_path = os.environ.get("CREATE_TABLES_SQL", "sql/create_tables.sql")
    repo_root = Path(__file__).resolve().parent.parent
    dataset_path = repo_root / dataset_dir
    create_tables_sql = repo_root / sql_path

    if not dataset_path.is_dir():
        print(f"Dataset directory not found: {dataset_path}", file=sys.stderr)
        sys.exit(1)
    if not create_tables_sql.is_file():
        print(f"SQL file not found: {create_tables_sql}", file=sys.stderr)
        sys.exit(1)

    # Create retailflow database if needed (connect to postgres)
    conn = get_connection("postgres")
    ensure_database(conn)

    conn = get_connection("retailflow")
    conn.autocommit = False

    # Run create_tables.sql
    with open(create_tables_sql, encoding="utf-8") as f:
        cur = conn.cursor()
        cur.execute(f.read())
        cur.close()
    conn.commit()
    print("Executed create_tables.sql")

    # Discover CSVs and load with COPY
    csv_files = sorted(dataset_path.glob("*.csv"))
    for csv_file in csv_files:
        table = csv_filename_to_table(csv_file.name)
        if table is None:
            print(f"Skipping {csv_file.name} (does not match olist_*_dataset.csv)")
            continue
        cur = conn.cursor()
        with open(csv_file, "rb") as f:
            cur.copy_expert(
                sql.SQL("COPY {} FROM STDIN WITH (FORMAT csv, HEADER true)").format(
                    sql.Identifier(table)
                ),
                f,
            )
        cur.close()
        conn.commit()
        print(f"Loaded {csv_file.name} -> {table}")

    conn.close()
    print("Ingestion complete.")


if __name__ == "__main__":
    main()
