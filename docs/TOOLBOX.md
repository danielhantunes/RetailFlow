# Data Engineering Toolbox VM

The **bootstrap VM** (`retailflow-dev-bootstrap-vm`) in the base VNet is used for **one-time or ad-hoc loads** (e.g. initial Olist CSV load via the Provision PostgreSQL for Olist workflow) and **inspecting Postgres** (psql, Python scripts). **Scheduled** Postgres → ADLS RAW ingestion is done by the **Azure Function** (see **Provision Postgres Ingest Function** workflow and [DATA_FLOW.md](DATA_FLOW.md)). The VM has no public IP; use **Azure Bastion** or **Run Command** to connect.

## 1. Setup on the VM

When you run **Provision PostgreSQL for Olist** with action **full** or **bootstrap_only**, the workflow installs the toolbox on the runner VM automatically. If you connect to the VM later (e.g. via Bastion), the tools are already there. To install or reinstall manually, run the toolbox setup script to install PostgreSQL client, Python 3, pip, psycopg2, pandas, git, and jq:

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

Connection details (host, user, password) come from Terraform postgres outputs or from Azure Key Vault (see below).

## 2. Retrieve secrets from Azure Key Vault

Store the PostgreSQL password and (optionally) the SSH private key in Azure Key Vault. Then retrieve them when needed.

### Create secrets in Key Vault (one-time)

If you have a Key Vault (e.g. for Databricks secret scope):

```bash
# PostgreSQL password (from Terraform: terraform output -raw postgres_password in terraform/postgres)
az keyvault secret set --vault-name <your-keyvault-name> --name postgres-toolbox-password --value "<password>"

# SSH private key for the toolbox VM (paste the private key content)
az keyvault secret set --vault-name <your-keyvault-name> --name toolbox-vm-ssh-private-key --value "$(cat ~/.ssh/toolbox_vm_rsa)"
```

### Retrieve secrets (Azure CLI)

```bash
# PostgreSQL password
export PGPASSWORD=$(az keyvault secret show --vault-name <your-keyvault-name> --name postgres-toolbox-password --query value -o tsv)

# SSH private key (save to file for SSH/Bastion)
az keyvault secret show --vault-name <your-keyvault-name> --name toolbox-vm-ssh-private-key --query value -o tsv > ~/.ssh/toolbox_vm_rsa
chmod 600 ~/.ssh/toolbox_vm_rsa
```

### Retrieve secrets (PowerShell)

```powershell
# PostgreSQL password
$env:PGPASSWORD = (Get-AzKeyVaultSecret -VaultName "<your-keyvault-name>" -Name "postgres-toolbox-password").SecretValue | Get-PlainText

# SSH private key
(Get-AzKeyVaultSecret -VaultName "<your-keyvault-name>" -Name "toolbox-vm-ssh-private-key").SecretValue | Get-PlainText | Out-File -FilePath "$env:USERPROFILE\.ssh\toolbox_vm_rsa" -Encoding utf8
```

Ensure your user or VM managed identity has **Get** permission on the Key Vault secrets.

## 3. SSH configuration (Bastion + key)

If you use Azure Bastion with SSH key authentication (after configuring the VM for key-based auth):

1. Store the SSH private key in Key Vault (see above) and retrieve it to a local file, e.g. `~/.ssh/toolbox_vm_rsa`.
2. In Azure Portal: connect to the VM via Bastion, choose **SSH key**, and upload or paste the private key.

For SSH from a machine that has Bastion host access, you can use a config like:

```
Host retailflow-bootstrap
  HostName retailflow-dev-bootstrap-vm
  User azureuser
  IdentityFile ~/.ssh/toolbox_vm_rsa
  ProxyCommand ssh -W %h:%p -p 22 <bastion-user>@<bastion-public-ip>
```

(Bastion often uses the browser or a different flow; the exact ProxyCommand depends on your Bastion setup.)

## 4. PostgreSQL access (psql)

Set connection env vars, then use the example script or run psql interactively:

```bash
export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
export PGUSER=retailflowadmin
export PGPASSWORD='...'
export PGDATABASE=retailflow

# Run example commands (list tables, describe, preview)
./scripts/toolbox_psql_examples.sh

# Interactive session
psql "host=$PGHOST user=$PGUSER dbname=$PGDATABASE sslmode=require"
# In psql: \dt   \d orders   SELECT * FROM orders LIMIT 10;
```

## 5. Python access (inspect tables)

```bash
export PGHOST=retailflow-ingest-pg.postgres.database.azure.com
export PGUSER=retailflowadmin
export PGPASSWORD='...'
export PGDATABASE=retailflow

# List tables and show first 5 rows of a table
python3 scripts/toolbox_inspect_postgres.py --table orders --rows 5
```

## 6. Optional: SSH key–only VM (Terraform)

To make the bootstrap VM key-only (no password), set the optional variable when applying the base module:

```hcl
# In terraform/base or where the module is called
bootstrap_vm_ssh_public_key = "ssh-rsa AAAA..."
```

Then re-apply base Terraform. Password auth is disabled; use the matching private key (e.g. from Key Vault) to connect via Bastion.

## 7. Security

- The VM is **private** (no public IP); use Bastion or Run Command.
- Prefer **SSH key** authentication; store the private key in Key Vault and use `bootstrap_vm_ssh_public_key` for key-only login.
- **Secrets**: store Postgres password (and SSH key) in Key Vault; retrieve at use time; avoid committing secrets.
- **Minimal surface**: the setup script installs only the packages needed for inspection and analysis.

## 8. Files

| File | Purpose |
|------|--------|
| `scripts/toolbox_setup.sh` | Install psql, Python, psycopg2, pandas, git, jq; optional Postgres connectivity check |
| `scripts/toolbox_psql_examples.sh` | Example psql commands: connect, list tables, describe, preview rows |
| `scripts/toolbox_inspect_postgres.py` | Python script: list tables from information_schema, preview rows of a table |
