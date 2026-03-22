# Data Engineering Toolbox VM

The **bootstrap VM** (`retailflow-dev-bootstrap-vm`) in the base VNet is used for **one-time or ad-hoc loads** (e.g. initial Olist CSV load via the Provision PostgreSQL for Olist workflow) and **inspecting Postgres** (psql, Python scripts). **Scheduled** Postgres → ADLS RAW ingestion is done by the **Azure Function** (see **Provision Postgres Ingest Function** workflow and [DATA_FLOW.md](DATA_FLOW.md)). The VM has no public IP.

## 1. Connect to the VM (default: Bastion + Microsoft Entra ID)

Use **Azure Bastion** and sign in with **Microsoft Entra ID** in the Portal connect flow — no SSH keys or local Key Vault steps for VM access. Deploy **Terraform Bastion (Dev)** when needed, then destroy to save cost; see [BASTION.md](BASTION.md). Ensure your user has **Virtual Machine Administrator Login** or **Virtual Machine User Login** on the VM (Terraform workflow input, repo variable, or manual IAM).

**Alternatives:** Azure **Run Command**, or Bastion with **SSH key** / password only if you configured the VM that way in base Terraform.

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

## 4. Python access (inspect tables)

```bash
export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
export PGUSER=retailflowadmin
export PGPASSWORD='...'
export PGDATABASE=retailflow

python3 scripts/toolbox_inspect_postgres.py --table orders --rows 5
```

## 5. Optional: SSH key–only VM (Terraform)

If you set `bootstrap_vm_ssh_public_key` in base Terraform, password login may be disabled; use the matching private key in the Bastion **SSH key** flow. This path is optional — **Entra ID + Bastion** is the documented default.

```hcl
bootstrap_vm_ssh_public_key = "ssh-rsa AAAA..."
```

## 6. Security

- The VM is **private** (no public IP); use **Bastion** (Entra ID) or Run Command.
- Do **not** commit Postgres passwords or keys; use Terraform outputs or your org’s secret process.
- **Minimal surface:** the setup script installs only the packages needed for inspection and analysis.

## 7. Files

| File | Purpose |
|------|--------|
| `scripts/toolbox_setup.sh` | Install psql, Python, psycopg2, pandas, git, jq; optional Postgres connectivity check |
| `scripts/toolbox_psql_examples.sh` | Example psql commands: connect, list tables, describe, preview rows |
| `scripts/toolbox_inspect_postgres.py` | Python script: list tables from information_schema, preview rows of a table |
