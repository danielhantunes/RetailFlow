# RetailFlow — Full Repository Tree

```
RetailFlow/
├── .github/
│   └── workflows/
│       ├── deploy-notebooks.yml
│       ├── deploy-jobs.yml
│       ├── promote-environment.yml
│       └── tests.yml
├── .gitignore
├── README.md
├── config/
│   ├── environments/
│   │   ├── dev.yaml
│   │   ├── stg.yaml
│   │   └── prod.yaml
│   └── schemas/
│       └── raw_orders.json
├── databricks/
│   ├── jobs/
│   │   └── retailflow_main_job.json
│   ├── lib/
│   │   └── README.md
│   └── notebooks/
│       ├── raw/
│       │   ├── 00_ingestion_metadata.py
│       │   ├── 01_ingest_orders_api.py
│       │   ├── 02_ingest_customers_api.py
│       │   ├── 03_ingest_products_csv.py
│       │   ├── 04_ingest_inventory.py
│       │   └── 05_ingest_clickstream.py
│       ├── bronze/
│       │   ├── 01_bronze_orders.py
│       │   ├── 02_bronze_customers.py
│       │   └── 03_bronze_products.py
│       ├── silver/
│       │   ├── 01_silver_orders.py
│       │   ├── 02_silver_customers.py
│       │   └── 03_silver_products.py
│       ├── gold/
│       │   ├── 01_gold_fact_orders.py
│       │   ├── 02_gold_fact_sales.py
│       │   ├── 03_gold_dim_customer_scd2.py
│       │   ├── 04_gold_dim_product.py
│       │   ├── 05_gold_daily_revenue_mart.py
│       │   ├── 06_gold_dim_store.py
│       │   └── 07_gold_inventory_snapshot.py
│       └── observability/
│           └── job_monitor.py
├── dlt/
│   └── pipelines/
│       └── bronze_silver_dlt.py
├── airflow/
│   ├── README.md
│   └── dags/
│       └── retailflow_medallion_dag.py
├── dbt/
│   └── retailflow/
│       ├── dbt_project.yml
│       ├── profiles.yml
│       └── models/
│           └── marts/
│               ├── daily_revenue.sql
│               └── sources.yml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── databricks/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── storage/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── key_vault/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── networking/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── scripts/
│   ├── bootstrap_raw_folders.sh
│   └── deploy_secret_scope.py
├── tests/
│   ├── requirements.txt
│   └── unit/
│       └── test_ingestion_metadata.py
└── docs/
    ├── ARCHITECTURE.md
    ├── DATA_FLOW.md
    ├── RAW_LAYER_DESIGN.md
    ├── UNITY_CATALOG.md
    ├── OBSERVABILITY.md
    ├── NEXT_STEPS.md
    └── REPOSITORY_TREE.md
```
