#!/usr/bin/env bash
# Example psql commands to inspect Azure PostgreSQL (Olist) from the toolbox VM.
# Set PGHOST, PGUSER, PGPASSWORD, PGDATABASE (e.g. retailflow) before running.
# Usage:
#   export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
#   export PGUSER=retailflowadmin
#   export PGPASSWORD='...'
#   export PGDATABASE=retailflow
#   ./toolbox_psql_examples.sh
# Or run individual commands interactively: psql -c "..."

set -euo pipefail

for v in PGHOST PGUSER PGPASSWORD PGDATABASE; do
  if [[ -z "${!v:-}" ]]; then
    echo "Set $v and re-run." >&2
    exit 1
  fi
done

echo "=== 1. Connect (one-liner) ==="
echo "psql \"host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require\" -c \"SELECT version();\""
psql "host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require" -c "SELECT version();"

echo ""
echo "=== 2. List tables ==="
psql "host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require" -c "\dt"

echo ""
echo "=== 3. Inspect table structure (e.g. orders) ==="
psql "host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require" -c "\d orders"

echo ""
echo "=== 4. Preview rows (orders, first 5) ==="
psql "host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require" -c "SELECT * FROM orders LIMIT 5;"

echo ""
echo "=== 5. Row counts (all tables) ==="
psql "host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require" -t -c "
SELECT 'orders: '        || COUNT(*) FROM orders
UNION ALL SELECT 'customers: '   || COUNT(*) FROM customers
UNION ALL SELECT 'order_items: ' || COUNT(*) FROM order_items
UNION ALL SELECT 'products: '    || COUNT(*) FROM products
UNION ALL SELECT 'sellers: '     || COUNT(*) FROM sellers;
"

echo ""
echo "Done. Use: psql \"host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require\" for an interactive session."
