#!/usr/bin/env bash
# Load Olist CSV files into PostgreSQL using COPY. Fast path; fail fast.
# Requires: PG_HOST, PG_USER, PGPASSWORD (or POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD).
# Usage: ./load_olist.sh [dataset_dir]
# Default dataset_dir: dataset (relative to repo root or cwd).

set -euo pipefail

DATASET_DIR="${1:-dataset}"
DBNAME="${PGDATABASE:-retailflow}"

# Support both PG_* and POSTGRES_* env vars
PG_HOST="${PG_HOST:-${POSTGRES_HOST:?Set PG_HOST or POSTGRES_HOST}}"
PG_USER="${PG_USER:-${POSTGRES_USER:?Set PG_USER or POSTGRES_USER}}"
export PGPASSWORD="${PGPASSWORD:-${POSTGRES_PASSWORD:?Set PGPASSWORD or POSTGRES_PASSWORD}}"

CONN="host=${PG_HOST} dbname=${DBNAME} user=${PG_USER}"

if [[ ! -d "$DATASET_DIR" ]]; then
  echo "Error: Dataset directory not found: $DATASET_DIR" >&2
  exit 1
fi

echo "==> Loading from $DATASET_DIR into PostgreSQL (${PG_HOST} / ${DBNAME})"

# Tables and their CSV files (table_name:csv_filename)
# Order: load referenced tables first (customers, products, sellers before orders/order_items)
load_table() {
  local table="$1"
  local file="$2"
  local path="${DATASET_DIR}/${file}"
  if [[ ! -f "$path" ]]; then
    echo "Error: $path not found" >&2
    exit 1
  fi
  echo "  Loading $table from $file ..."
  psql "$CONN" -v ON_ERROR_STOP=1 -c "\\copy ${table} FROM '${path}' WITH (FORMAT csv, HEADER true)"
  echo "  Done: $table"
}

# Load in dependency-friendly order
load_table "customers"       "customers.csv"
load_table "orders"          "orders.csv"
load_table "products"        "products.csv"
load_table "sellers"         "sellers.csv"
load_table "order_items"     "order_items.csv"
load_table "order_reviews"   "order_reviews.csv"
load_table "order_payments"  "order_payments.csv"
load_table "geolocation"     "geolocation.csv"

echo "==> All tables loaded successfully."
