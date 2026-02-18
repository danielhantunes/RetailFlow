# Unity Catalog Structure (RetailFlow)

## Catalogs and schemas

| Environment | Catalog       | Schemas                          |
|-------------|---------------|-----------------------------------|
| Dev         | retailflow_dev  | raw, bronze, silver, gold       |
| Stg         | retailflow_stg  | raw, bronze, silver, gold       |
| Prod        | retailflow_prod | raw, bronze, silver, gold       |

## Suggested roles

- **raw_ingestion** — USAGE on catalog, WRITE on raw schema.
- **bronze_reader** — SELECT on bronze.
- **silver_reader** — SELECT on silver.
- **gold_reader** — SELECT on gold.
- **analytics** — SELECT on gold + silver (for ad-hoc).
- **platform_admin** — ALL PRIVILEGES on catalog (for job runs and DLT).

## Secret scope and Key Vault

- Create a secret scope backed by Azure Key Vault (e.g. `retailflow-keyvault`).
- Store: `orders-api-key`, `customers-api-key`, `sql-db-connection-string`, etc.
- Grant the Databricks workspace MSI **Get** and **List** on the Key Vault access policy so the scope can resolve secrets.

## Access policies

- Use Unity Catalog grants to restrict tables by role; use row/column filters where needed.
- External locations: one per storage account/container for RAW and processed; grant to catalog.

## Example SQL (run in Databricks)

```sql
CREATE CATALOG IF NOT EXISTS retailflow_dev;
CREATE SCHEMA IF NOT EXISTS retailflow_dev.raw;
CREATE SCHEMA IF NOT EXISTS retailflow_dev.bronze;
CREATE SCHEMA IF NOT EXISTS retailflow_dev.silver;
CREATE SCHEMA IF NOT EXISTS retailflow_dev.gold;

CREATE ROLE raw_ingestion;
GRANT USAGE ON CATALOG retailflow_dev TO raw_ingestion;
GRANT USE SCHEMA, CREATE TABLE, MODIFY ON SCHEMA retailflow_dev.raw TO raw_ingestion;
```
