# Postgres Ingest Azure Function

Azure Function App (**Python v2** programming model: **timer** + **`GET|POST /api/postgres_ingest_run`**) that reads from Azure PostgreSQL and writes to ADLS Gen2 RAW. Run **after** Terraform Platform (Dev), **Terraform Data Lake (Dev)** (ADLS), and Postgres (apply).

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
- **App settings:** Postgres connection (from Postgres state), RAW storage/container, AzureWebJobsStorage, **`AzureWebJobsFeatureFlags=EnableWorkerIndexing`** (required for Python v2 so functions register in the host), `POSTGRES_TIMER_SCHEDULE`.
- **Runtime controls:** `INGESTION_MODE` (`initial`/`incremental`), `RAW_FORMAT` (`jsonl`), optional `INGEST_TABLE_CONFIG_JSON`, `INGEST_CHUNK_SIZE`, optional `RAW_PREFIX` (default `postgres_ingest`), and ADLS watermark checkpoints under `_control/postgres_watermarks/`.
- **RAW layout:** `{RAW_PREFIX}/{table}/ingestion_date=.../hour=.../batch_id=.../chunk_*.jsonl` plus manifests under `{RAW_PREFIX}/_runs/...`.
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

**Provision Postgres Ingest Function** (`provision_postgres_ingest_function.yml`): `plan` | `apply` | `destroy`. On apply, builds a zip from `functions/postgres_to_raw` and deploys with **`az webapp deploy`** (10-minute operation timeout, Kudu warmup, retries). Older **`config-zip`** often hits a **30s SCM read timeout** during `validate_app_settings_in_scm`; prefer the workflow as committed.

**Manual runs:** `run_postgres_raw_initial_load.yml`, `run_postgres_raw_incremental.yml` set `INGESTION_MODE`, restart the app, **GET**-probe then **POST** `https://<functionapp>.azurewebsites.net/api/postgres_ingest_run` with the **host master key** (`az functionapp keys list`). Retries and **`AZURE_CORE_HTTP_TIMEOUT`** reduce transient ARM timeouts. If **GET** returns **404**, redeploy the function zip (**Provision Postgres Ingest Function** apply) and confirm **`AzureWebJobsFeatureFlags=EnableWorkerIndexing`** is set.

**Payload:** `host.json` sets **`functionTimeout`** (e.g. 2 hours) so long **initial** loads can complete over HTTP before Azure closes the request.

Run manifests: `{RAW_PREFIX}/_runs/.../run_<id>.json` (default prefix `postgres_ingest`).

## Troubleshooting

### Zip deploy or SCM timeouts

- **Symptom:** `Read timed out` / **HTTPSConnectionPool** to **`<app>.scm.azurewebsites.net`** during **Provision Postgres Ingest Function** deploy.
- **Mitigation:** Workflow uses **`az webapp deploy`** with **`--timeout 600000`** and retries. Re-run the workflow; ensure SCM is reachable from **GitHub-hosted** runners (no blanket block on `*.azurewebsites.net`).

### ARM `Request Timeout` on `az functionapp keys list`

- **Mitigation:** **Run Postgres RAW** workflows retry key fetch and set **`AZURE_CORE_HTTP_TIMEOUT`**. Re-run if Azure RM is slow.

### Elastic Premium quota (EP1) — `401 Unauthorized` / “additional quota” / `ElasticPremium VMs: 0`

This module uses **Elastic Premium EP1** (`azurerm_service_plan` with `sku_name = "EP1"`) so the Linux Function App can use **VNet integration** to reach private PostgreSQL.

Azure sometimes returns **HTTP 401** with a body mentioning **quota** and **`Current Limit (ElasticPremium VMs): 0`**. That is a **subscription quota** issue in the **Function App region** (default **East US 2**), not an OIDC or Terraform auth problem.

**What to do**

1. **Request a quota increase** (preferred): Azure Portal → **Help + support** → **Create a support request** → issue type **Service and subscription limits (quotas)**. For **Quota type**, choose **Function or Web App (Windows and Linux)** (not always visible under generic Usage + quotas). On **Additional details**, use **Enter details** to set **Region** (e.g. **East US 2**), deployment type, **App Service plan SKU** (Elastic Premium / **EP1**), and the **new worker VM limit** you need; paste your Terraform error if asked. Step-by-step (with the same error pattern): [Microsoft Q&A — Premium Function App quota / EP1](https://learn.microsoft.com/answers/questions/5658740/im-trying-to-create-a-premium-function-app-and-it). See also [Microsoft Learn — regional quota requests](https://learn.microsoft.com/azure/azure-portal/supportability/regional-quota-requests).
2. **If you cannot find a quota row** in **Subscriptions → Usage + quotas**: the Elastic Premium limit is often **not labeled clearly** in the portal UI. Use the **support request** path above (quota type **Function or Web App**) or open a ticket with the error text; support routes it to the right limit.
3. **CLI (optional):** `az appservice list-usage --location eastus2 -o table` may show related usage names for your subscription.
4. **After quota is approved:** Re-run **`provision_postgres_ingest_function`** **apply**. A failed apply may have created the subnet, Application Insights, and internal storage account already; Terraform should complete the plan and App Service plan on retry.

**Note:** Some subscription **offers** (e.g. certain trial/sponsored SKUs) may not allow Elastic Premium until you move workloads to **pay-as-you-go** or get allowance from support.
