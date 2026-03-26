# Data Engineering Toolbox VM

The **bootstrap VM** (`retailflow-dev-bootstrap-vm`) in the base VNet is used for **one-time or ad-hoc loads** (e.g. initial Olist CSV load via the Provision PostgreSQL for Olist workflow) and **inspecting Postgres** (psql, Python scripts). **Scheduled** Postgres → ADLS RAW ingestion is done by the **Azure Function** (see **Provision Postgres Ingest Function** workflow and [DATA_FLOW.md](DATA_FLOW.md)). The VM has no public IP.

## 1. Connect to the VM (default: Bastion + Microsoft Entra ID)

Use **Azure Bastion** and sign in with **Microsoft Entra ID** in the Portal connect flow — no SSH keys or local Key Vault steps for VM access. Deploy **Terraform Bastion (Dev)** when needed, then destroy to save cost; see [BASTION.md](BASTION.md). Ensure your user has **Virtual Machine Administrator Login** or **Virtual Machine User Login** on the VM (Terraform workflow input, repo variable, or manual IAM).

**Alternatives:** Azure **Run Command**, or Bastion with **SSH key** / password only if you configured the VM that way in `terraform/bootstrap_vm`.

## 2. Setup on the VM

When you run **Provision PostgreSQL for Olist** with action **full** or **bootstrap_only**, the workflow installs the toolbox on the runner VM automatically. If you connect later (e.g. via Bastion), the tools may already be there. To install or reinstall manually, run the toolbox setup script (PostgreSQL client, Python 3, pip, psycopg2, pandas, git, jq):

```bash
# Optional: set Postgres env to verify connectivity at the end of setup
export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
export PGUSER=retailflowadmin
export PGPASSWORD='<password from Terraform postgres output>'
export PGDATABASE=retailflow

cd /path/to/repo/scripts  # or copy toolbox_setup.sh to the VM
chmod +x toolbox_setup.sh
./toolbox_setup.sh
```

Connection details (host, user, password) come from **Terraform postgres outputs** (or your team’s usual secret handling — e.g. Databricks/Key Vault is for **Databricks** secret scopes, not required for Entra + Bastion VM login).

## 3. PostgreSQL access (psql)

On the VM (after connecting via Bastion), set connection env vars:

```bash
export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
export PGUSER=retailflowadmin
export PGPASSWORD='...'   # from Terraform postgres output; do not commit
export PGDATABASE=retailflow

# Run example commands (list tables, describe, preview)
./scripts/toolbox_psql_examples.sh

# Interactive session
psql "host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require"
# In psql: \dt   \d orders   SELECT * FROM orders LIMIT 10;
```

### Passwordless psql via `.pgpass`

To avoid entering the PostgreSQL password for each `psql` command, create `~/.pgpass` on the VM:

```bash
cat > ~/.pgpass <<'EOF'
retailflow-ingest-pg.postgres.database.azure.com:5432:retailflow:retailflowadmin:<POSTGRES_PASSWORD>
EOF
chmod 600 ~/.pgpass
```

Then use env vars without `PGPASSWORD`:

```bash
export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
export PGUSER=retailflowadmin
export PGDATABASE=retailflow
export PGPORT=5432
export PGSSLMODE=require

psql -c "select now();"
psql -c "\dt"
```

Notes:
- `.pgpass` format is `hostname:port:database:username:password`.
- Permissions must be `600` or `psql` ignores the file.
- Never commit `.pgpass`.

## 4. Python access (inspect tables)

```bash
export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
export PGUSER=retailflowadmin
export PGPASSWORD='...'
export PGDATABASE=retailflow

python3 scripts/toolbox_inspect_postgres.py --table orders --rows 5
```

## 5. Olist load validation snapshot (example)

After running **Provision PostgreSQL for Olist** (`full` or `bootstrap_only`), run a quick row-count check from the VM. Treat these counts as a **validation snapshot** (observed for one run), not a strict contract.

```sql
SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation;
```

Example output from a successful load:

| table_name | total_rows |
|------|--------|
| customers | 99441 |
| orders | 99441 |
| order_items | 112650 |
| products | 32951 |
| sellers | 3095 |
| order_reviews | 99224 |
| order_payments | 103886 |
| geolocation | 1000163 |

## Data Quality Validation (Source Layer - PostgreSQL)

After running **Provision PostgreSQL for Olist** (`provision_olist_postgres.yml`, action `full` or `bootstrap_only`), you can run optional ad-hoc SQL validations directly in PostgreSQL from the bootstrap VM.

Set connection variables once:

```bash
export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
export PGUSER=retailflowadmin
export PGDATABASE=retailflow
export PGSSLMODE=require
export PG_CONN="host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=$PGSSLMODE"
```

### 1) CUSTOMERS

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total,
    COUNT(customer_id) AS not_null_id,
    COUNT(DISTINCT customer_id) AS unique_id,
    COUNT(*) - COUNT(customer_id) AS null_id
FROM customers;
"
```

### 2) ORDERS (dates + consistency)

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total,
    MIN(order_purchase_timestamp) AS min_date,
    MAX(order_purchase_timestamp) AS max_date,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS null_status
FROM orders;
"
```

### 3) ORDER_ITEMS (values)

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE price IS NULL OR price = '') AS null_price,
    MIN(NULLIF(price, '')::numeric) AS min_price,
    MAX(NULLIF(price, '')::numeric) AS max_price,
    AVG(NULLIF(price, '')::numeric) AS avg_price
FROM order_items;
"
```

### 4) ORDER_PAYMENTS (financial validation)

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total,
    SUM(NULLIF(payment_value, '')::numeric) AS total_value,
    COUNT(*) FILTER (
        WHERE NULLIF(payment_value, '')::numeric <= 0
    ) AS invalid_values
FROM order_payments;
"
```

### 5) ORDER_REVIEWS (domain)

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (
        WHERE NULLIF(review_score, '')::numeric < 1
           OR NULLIF(review_score, '')::numeric > 5
    ) AS invalid_scores
FROM order_reviews;
"
```

### 6) GEOLOCATION (missing data)

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE geolocation_lat IS NULL OR geolocation_lng IS NULL) AS missing_coords
FROM geolocation;
"
```

### 7) PRODUCTS (missing fields)

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS null_weight
FROM products;
"
```

### 8) SELLERS (unicity)

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total,
    COUNT(DISTINCT seller_id) AS unique_sellers
FROM sellers;
"
```

### 9) Integrity (orders -> customers)

```bash
psql "$PG_CONN" -c "
SELECT COUNT(*) AS orphan_orders
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
"
```

### 10) Integrity (order_items -> orders)

```bash
psql "$PG_CONN" -c "
SELECT COUNT(*) AS orphan_items
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
"
```

### 11) Distribution (business)

```bash
psql "$PG_CONN" -c "
SELECT order_status, COUNT(*)
FROM orders
GROUP BY order_status
ORDER BY COUNT(*) DESC;
"
```

### 12) Real duplicates (not only DISTINCT)

```bash
psql "$PG_CONN" -c "
SELECT customer_id, COUNT(*)
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
"
```

### 13) Date consistency

```bash
psql "$PG_CONN" -c "
SELECT COUNT(*) AS invalid_dates
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;
"
```

### 14) Broken rows

```bash
psql "$PG_CONN" -c "
SELECT COUNT(*) AS incomplete_rows
FROM orders
WHERE order_id IS NULL
   OR customer_id IS NULL;
"
```

### 15) Table relationship (business consistency)

```bash
psql "$PG_CONN" -c "
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM orders;
"
```

### 16) Temporal range (orders)

```bash
psql "$PG_CONN" -c "
SELECT
    MIN(order_purchase_timestamp),
    MAX(order_purchase_timestamp)
FROM orders;
"
```

Interpretation tips:
- `orphan_orders` and `orphan_items` should be `0`.
- `invalid_scores` should be `0` for valid review score domain `[1, 5]`.
- `invalid_dates` should be `0`.
- `incomplete_rows` should be `0`.

## 6. Optional: SSH key-only VM (Terraform)

If you set `bootstrap_vm_ssh_public_key` in base Terraform, password login may be disabled; use the matching private key in the Bastion **SSH key** flow. This path is optional — **Entra ID + Bastion** is the documented default.

```hcl
bootstrap_vm_ssh_public_key = "ssh-rsa AAAA..."
```

## 7. Security

- The VM is **private** (no public IP); use **Bastion** (Entra ID) or Run Command.
- Do **not** commit Postgres passwords or keys; use Terraform outputs or your org’s secret process.
- **Minimal surface:** the setup script installs only the packages needed for inspection and analysis.

## 8. Files

| File | Purpose |
|------|--------|
| `scripts/toolbox_setup.sh` | Install psql, Python, psycopg2, pandas, git, jq; optional Postgres connectivity check |
| `scripts/toolbox_psql_examples.sh` | Example psql commands: connect, list tables, describe, preview rows |
| `scripts/toolbox_inspect_postgres.py` | Python script: list tables from information_schema, preview rows of a table |
