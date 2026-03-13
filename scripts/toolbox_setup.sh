#!/usr/bin/env bash
# Data engineering toolbox setup for the bootstrap VM.
# Installs: postgresql-client, Python 3, pip, psycopg2, pandas, git, jq.
# Verifies connectivity to Azure PostgreSQL (retailflow-ingest-pg) when PGHOST is set.
# Run on the VM after first login (e.g. via Bastion) or via Azure Run Command.
# Usage: PGHOST=... PGUSER=... PGPASSWORD=... PGDATABASE=retailflow ./toolbox_setup.sh

set -euo pipefail

echo "==> Updating package list..."
sudo apt-get update -qq

echo "==> Installing PostgreSQL client (psql)..."
sudo apt-get install -y -qq postgresql-client

echo "==> Installing Python 3 and pip..."
sudo apt-get install -y -qq python3 python3-pip python3-venv

echo "==> Installing git and jq..."
sudo apt-get install -y -qq git jq

echo "==> Installing Python packages (psycopg2, pandas)..."
pip3 install --user --break-system-packages psycopg2-binary pandas 2>/dev/null || pip3 install --user psycopg2-binary pandas

echo "==> Toolbox packages installed."

if [[ -n "${PGHOST:-}" ]]; then
  echo "==> Verifying connectivity to PostgreSQL at $PGHOST..."
  if psql -c "SELECT 1 AS connected;" 2>/dev/null; then
    echo "==> PostgreSQL connectivity OK."
  else
    echo "==> WARNING: Could not connect to PostgreSQL. Set PGHOST, PGUSER, PGPASSWORD, PGDATABASE and ensure the VM can reach the server (same VNet)."
    exit 1
  fi
else
  echo "==> PGHOST not set; skipping PostgreSQL connectivity check. Set PGHOST, PGUSER, PGPASSWORD, PGDATABASE to verify."
fi

echo "==> Done."
