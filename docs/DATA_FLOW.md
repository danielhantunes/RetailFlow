# RetailFlow — Data Flow

## End-to-End Flow

1. **Ingestion**  
   Notebooks (or ADF/Airflow) pull from REST APIs, SQL DB, files (JSON/CSV), and write **unchanged** payloads into ADLS Gen2 under `/data/raw/<entity>/ingestion_date=YYYY-MM-DD/`. Metadata (e.g. `_ingestion_ts`, `_source_file`) can be added at write time without changing the payload body.

2. **RAW → BRONZE**  
   Delta Live Tables or batch notebooks read from RAW paths, parse (flatten JSON, parse CSV), enforce schema, add audit columns, and write Delta tables in the Bronze schema. Incremental processing is done by `ingestion_date` or checkpoint.

3. **BRONZE → SILVER**  
   DLT or notebooks read Bronze, apply cleansing, deduplication (e.g. by business key + timestamp), joins to resolve FKs, and write Silver Delta tables. Optional expectations for data quality.

4. **SILVER → GOLD**  
   Aggregate and join Silver into facts (e.g. `fact_sales`, `fact_orders`), build dimensions (customer SCD2, product, store), inventory snapshots, and marts (e.g. daily revenue). Optimize with Z-Order and partitioning.

5. **Consumption**  
   Power BI, Tableau, Databricks SQL, and other tools query Gold (and optionally Silver) via Unity Catalog.

## Per-Source Flows

| Source | RAW Path | Bronze Table | Silver Table | Gold Usage |
|--------|----------|--------------|--------------|------------|
| Orders API | `/data/raw/orders/` | `bronze_orders` | `silver_orders` | `fact_orders`, daily revenue |
| Customers API | `/data/raw/customers/` | `bronze_customers` | `silver_customers` | `dim_customer` (SCD2) |
| Products CSV | `/data/raw/products/` | `bronze_products` | `silver_products` | `dim_product` |
| Inventory | `/data/raw/inventory/` | `bronze_inventory` | `silver_inventory` | `fact_inventory_snapshot` |
| Clickstream | `/data/raw/clickstream/` | `bronze_clickstream` | `silver_clickstream` | Analytics / marts |
| Payments | `/data/raw/payments/` | `bronze_payments` | `silver_payments` | `fact_orders`, revenue |
| Store sales (SQL) | `/data/raw/store_sales/` | `bronze_store_sales` | `silver_store_sales` | `fact_sales` |

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
