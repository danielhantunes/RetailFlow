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

## Backend

Use the same state backend as other layers; key: `retailflow-postgres-ingest-function.tfstate`.

## Variables

- `tfstate_*`: Backend and remote state config (set in CI).
- `function_subnet_cidr`: Subnet for the function (default `10.139.6.0/24`).
- `raw_container_name`: ADLS container for RAW (default `raw`).
- `postgres_password`: Optional override; if empty, uses value from Postgres Terraform state.

## CI/CD

**Provision Postgres Ingest Function** workflow (`provision_postgres_ingest_function.yml`): `plan` | `apply` | `destroy`. On apply, the workflow also deploys the function code from `functions/postgres_to_raw`.
