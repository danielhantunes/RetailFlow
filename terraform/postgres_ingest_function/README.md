# Postgres Ingest Azure Function

Azure Function App (timer-triggered) that reads from Azure PostgreSQL and writes to ADLS Gen2 RAW. Run **after** Terraform Platform (Dev), **Terraform Data Lake (Dev)** (ADLS), and Postgres (apply).

## Prerequisites

- Terraform Platform (Dev) applied (VNet, RG).
- Terraform Data Lake (Dev) applied (`retailflow-dev-adls.tfstate`) — function reads ADLS id/name from this state.
- Postgres layer applied (`retailflow-ingest-pg.tfstate`).

## What it creates

- **Subnet** in the platform VNet (delegation `Microsoft.Web/serverFarms`) for Function App VNet integration.
- **Storage account** for the Function App (Azure requirement).
- **App Service Plan** (Elastic Premium EP1) for VNet integration.
- **Linux Function App** (Python 3.11) with VNet integration, managed identity, Application Insights.
- **Role assignment:** Function's managed identity → Storage Blob Data Contributor on the **Data Lake** storage account (from `terraform/adls` state).
- **App settings:** Postgres connection (from Postgres state), RAW storage/container, AzureWebJobsStorage.
- **Runtime controls:** `INGESTION_MODE` (`initial`/`incremental`), `RAW_FORMAT` (`jsonl`), optional `INGEST_TABLE_CONFIG_JSON`, `INGEST_CHUNK_SIZE`, and ADLS watermark checkpoints under `_control/postgres_watermarks/`.
- **Restart-safe ingestion:** chunked extraction with checkpoint cursor after each chunk.
- **Timer:** `POSTGRES_TIMER_SCHEDULE` (default every 15 minutes in Azure).

## Backend

Same state backend as other layers; key: `retailflow-postgres-ingest-function.tfstate`.

## Variables

- `tfstate_*`: Backend and remote state keys (platform, **adls**, postgres).
- `function_subnet_cidr`: default `10.139.6.0/24`.
- `raw_container_name`: default `raw`.
- `postgres_password`: optional override.

## CI/CD

**Provision Postgres Ingest Function** (`provision_postgres_ingest_function.yml`): `plan` | `apply` | `destroy`. On apply, deploys code from `functions/postgres_to_raw`.

Runtime: `run_postgres_raw_initial_load.yml`, `run_postgres_raw_incremental.yml` (manual triggers).

Run manifests under `postgres_ingest/_runs/.../run_<id>.json`.
