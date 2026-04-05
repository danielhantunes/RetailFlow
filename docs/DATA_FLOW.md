# RetailFlow — Data Flow

## Target End-to-End Flow

The platform is built around this flow (e.g. for Olist / retail data):

```
PostgreSQL (source, e.g. Olist)
      │
      ▼
Azure Function  (timer + optional HTTP for CI)  →  reads Postgres, writes to RAW
      │
      ▼
ADLS RAW  (immutable, partition by ingestion_date)
      │
      ▼
Databricks  Bronze → Silver  (Delta, Unity Catalog)
      │
      ▼
Snowflake  (Gold layer / serving)
      │
      ▼
dbt models  (marts, transformations)
      │
      ▼
Analytics marts  (Power BI, Tableau, reporting)
```

---

## Postgres → Azure Function to RAW {#postgres-azure-function-to-raw}

- **Source:** Azure Database for PostgreSQL Flexible Server (e.g. Olist schema), private in the base VNet. Provisioned via `terraform/postgres`; initial load via **Provision PostgreSQL for Olist** workflow (VM toolbox runs the one-time CSV COPY).
- **Scheduled ingestion:** An **Azure Function** (Python v2; **timer** e.g. every 15 min) runs in the base VNet (VNet integration), reads from Postgres (query-based incremental or full), and writes **JSONL** to ADLS Gen2 **RAW** filesystem. **Layout** (defaults): prefix `postgres_ingest/` → `{table}/ingestion_date=YYYY-MM-DD/hour=HH/batch_id={run}/chunk_NNNNN.jsonl`, plus run manifests under `postgres_ingest/_runs/...` and watermarks under `_control/postgres_watermarks/` (override via app settings `RAW_PREFIX`, `WATERMARK_CONTROL_PREFIX`). **On-demand / CI:** `GET|POST /api/postgres_ingest_run` with host or function key (`GET` = health only; `POST` runs ingestion, same logic as the timer). Provision via **Provision Postgres Ingest Function** (`provision_postgres_ingest_function.yml`) — run after Terraform Platform (Dev), Terraform Data Lake (Dev), and Postgres (apply). Code: `functions/postgres_to_raw`. The function uses managed identity for ADLS and app settings for Postgres connection (from Postgres Terraform state). **Where to look in Portal:** RAW container on the **Data Lake** storage account from Terraform (default dev account name **`retailflowdevdls`**). `config/environments/dev.yaml` uses the same default for `storage.account_name` / `base_path`; override if your deployment differs.
- **VM toolbox:** Used for **one-time or ad-hoc loads** (e.g. initial Olist load) and **inspecting Postgres** (psql, Python). It is **not** used for scheduled Postgres → RAW ingestion. See [TOOLBOX.md](TOOLBOX.md).
- **RAW:** Immutable; append-only; partition by `ingestion_date`. Supports replay and schema evolution. Other sources (REST APIs, CSVs) can also be ingested to RAW by notebooks or pipelines.

---

## RAW → Bronze → Gold (Databricks)

1. **Ingestion to RAW**  
   The **Azure Function** (Postgres → RAW) or notebooks (APIs, files) write **unchanged** payloads into ADLS Gen2 under the RAW filesystem. **Postgres function:** `postgres_ingest/{table}/ingestion_date=.../hour=.../batch_id=.../*.jsonl` (see above). **Notebooks / APIs** may use other prefixes (e.g. `orders/`, `data/raw/...`) depending on job config. Metadata (e.g. `_ingestion_ts`, `_batch_id`) is added in the function’s JSON lines.

2. **RAW → BRONZE**  
   Delta Live Tables or batch notebooks read from RAW paths, parse (flatten JSON, parse CSV), enforce schema, add audit columns, and write Delta tables in the Bronze schema. Incremental processing by `ingestion_date` or checkpoint.

3. **BRONZE → SILVER**  
   DLT or notebooks read Bronze, apply cleansing, deduplication (e.g. by business key + timestamp), joins to resolve FKs, and write Silver Delta tables. Optional expectations for data quality.

4. **SILVER → GOLD**  
   Aggregate and join Silver into facts (e.g. `fact_sales`, `fact_orders`), dimensions (customer SCD2, product, store), inventory snapshots, and marts (e.g. daily revenue). Gold lives in Delta (Unity Catalog) and is synced or exposed to **Snowflake**.

5. **Snowflake & dbt**  
   Gold layer is the serving layer in **Snowflake**. **dbt** models run on Gold to produce analytics marts. **Airflow** (optional) orchestrates the medallion pipeline.

6. **Consumption**  
   Power BI, Tableau, Databricks SQL, and other tools query Gold (Snowflake or Databricks) for analytics marts.

## Per-Source Flows

The **PostgreSQL / Azure Function** path and **API / CSV notebooks** below match notebooks in this repo where noted. Rows marked **(planned)** describe target layouts; Bronze/Silver notebooks for those entities are not all present yet—see `databricks/notebooks/`.

| Source | Ingestion | RAW Path | Bronze (Unity Catalog) | Silver | Gold usage |
|--------|-----------|----------|------------------------|--------|------------|
| **PostgreSQL (Olist)** | **Azure Function** (timer + HTTP); VM toolbox = one-time load + inspection | **`postgres_ingest/{table}/...`** — tables ingested by default include `orders`, `order_items`, `order_payments`, `order_reviews`, `customers`, `products`, `sellers`, `geolocation` | **`bronze.orders`**, **`bronze.customers`**, **`bronze.products`**, **`bronze.order_items`**, **`bronze.order_payments`**, **`bronze.order_reviews`**, **`bronze.sellers`**, **`bronze.geolocation`** (see `databricks/notebooks/bronze/`) | `silver.orders`, `silver.customers`, `silver.products` (others TBD) | `fact_orders`, `dim_customer`, marts (as implemented in `gold/`) |
| Orders API | Notebooks | e.g. `data/raw/orders/` | `bronze.orders` (same table; path via Spark config) | `silver.orders` | `fact_orders`, daily revenue |
| Customers API | Notebooks | e.g. `data/raw/customers/` | `bronze.customers` | `silver.customers` | `dim_customer` (SCD2) |
| Products CSV | Notebooks | e.g. `data/raw/products/` (or Postgres JSONL) | `bronze.products` | `silver.products` | `dim_product` |
| Inventory | Notebooks | `data/raw/inventory/` | *(planned)* `bronze.inventory` | *(planned)* | `fact_inventory_snapshot` |
| Clickstream | Notebooks | `data/raw/clickstream/` | *(planned)* | *(planned)* | Analytics / marts |
| Store sales (SQL) | Notebooks | `data/raw/store_sales/` | *(planned)* | *(planned)* | `fact_sales` |

## Incremental Processing

- **RAW:** Append-only per `ingestion_date`; idempotency by (source + batch_id + path).
- **Bronze/Silver/Gold:** Use Delta checkpoint or `ingestion_date` / `updated_at` watermarks to process only new or changed records; merge or append as per design.

## Orchestration Order

Recommended dependency order for pipelines:

1. Ingest all RAW (parallel where possible).
2. Bronze: all entities (parallel).
3. Silver: dimensions first (customers, products, stores), then facts (orders, sales, payments, clickstream).
4. Gold: dimensions then facts and marts.

This is reflected in the example Databricks job chain and optional Airflow DAG.
