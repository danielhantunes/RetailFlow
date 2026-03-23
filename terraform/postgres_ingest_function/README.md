# Postgres Ingest Azure Function

Azure Function App (timer-triggered) that reads from Azure PostgreSQL and writes to ADLS Gen2 RAW. Run **after** Terraform Base (Dev) and Postgres (apply).

## Prerequisites

- Terraform Base (Dev) applied (VNet, ADLS, resource group).
- Postgres layer applied (`retailflow-ingest-pg.tfstate` exists in the same backend).

## What it creates

- **Subnet** in the base VNet (delegation `Microsoft.Web/serverFarms`) for Function App VNet integration.
- **Storage account** for the Function App (Azure requirement).
- **App Service Plan** (Elastic Premium EP1) for VNet integration.
- **Linux Function App** (Python 3.11) with VNet integration, managed identity, Application Insights.
- **Role assignment:** Function's managed identity → Storage Blob Data Contributor on the base ADLS account.
- **App settings:** Postgres connection (from Postgres state), RAW storage/container, AzureWebJobsStorage.
- **Runtime controls:** `INGESTION_MODE` (`initial`/`incremental`), `RAW_FORMAT` (`jsonl`), optional `INGEST_TABLE_CONFIG_JSON`, `INGEST_CHUNK_SIZE`, and ADLS watermark checkpoints under `_control/postgres_watermarks/`.
- **Restart-safe ingestion:** extraction runs in chunks and updates checkpoint cursor (`last_watermark` + `last_pk` + `last_chunk_index`) after each successful chunk write, so reruns continue from the last committed chunk.
- **Timer schedule app setting:** `POSTGRES_TIMER_SCHEDULE` is set to a low-frequency default so ingestion is typically triggered by GitHub workflows.

## Backend

Use the same state backend as other layers; key: `retailflow-postgres-ingest-function.tfstate`.

## Variables

- `tfstate_*`: Backend and remote state config (set in CI).
- `function_subnet_cidr`: Subnet for the function (default `10.139.6.0/24`).
- `raw_container_name`: ADLS container for RAW (default `raw`).
- `postgres_password`: Optional override; if empty, uses value from Postgres Terraform state.

## CI/CD

**Provision Postgres Ingest Function** workflow (`provision_postgres_ingest_function.yml`): `plan` | `apply` | `destroy`. On apply, the workflow also deploys the function code from `functions/postgres_to_raw`.

Runtime workflows:
- `run_postgres_raw_initial_load.yml`: manual one-time trigger (`INGESTION_MODE=initial`).
- `run_postgres_raw_incremental.yml`: scheduled/manual trigger (`INGESTION_MODE=incremental`, every 15 minutes).

Run manifests:
- Each run writes a manifest JSON under `postgres_ingest/_runs/.../run_<id>.json` with table/chunk progress and status.
