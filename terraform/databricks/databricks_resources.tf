# Dev cluster and Jobs pipeline — created only when databricks_host is set (second apply).
# Authenticate to Databricks via Azure AD (same SP as Azure RM). Add the app to the Databricks workspace.

locals {
  create_databricks_resources = var.databricks_host != ""
}

# Resolve LTS runtime and smallest node type at apply time (faster provisioning, fewer API lookups).
# Only run when we have a real workspace host (second apply).
data "databricks_spark_version" "latest_lts" {
  count                = local.create_databricks_resources ? 1 : 0
  long_term_support    = true
}

# Smallest node type with local disk (provider may not support min_cores/max_cores in this version).
data "databricks_node_type" "smallest" {
  count      = local.create_databricks_resources ? 1 : 0
  local_disk = true
}

# DEV: single-node cluster for development (see docs/COMPUTE_AND_COST.md).
# driver_node_type_id and data sources reduce creation time (fewer API lookups, fixed types).
resource "databricks_cluster" "dev" {
  count = local.create_databricks_resources ? 1 : 0

  cluster_name            = "retailflow-dev-single-node"
  spark_version           = data.databricks_spark_version.latest_lts[0].id
  node_type_id            = data.databricks_node_type.smallest[0].id
  driver_node_type_id     = data.databricks_node_type.smallest[0].id
  num_workers             = 1
  autotermination_minutes = 30

  spark_conf = {
    "spark.sql.adaptive.enabled" = "true"
  }

  azure_attributes {
    availability = "ON_DEMAND_AZURE"
  }

  custom_tags = merge(var.tags, { "project" = "RetailFlow", "env" = "dev" })
}

# PROD-style job: RetailFlow_Main_Pipeline with job cluster (1–2 workers, Photon), terminates after run
resource "databricks_job" "main_pipeline" {
  count = local.create_databricks_resources ? 1 : 0

  name                 = "RetailFlow_Main_Pipeline"
  description          = "RAW → Bronze → Silver → Gold for retail data platform"
  timeout_seconds      = 0
  max_concurrent_runs   = 1

  schedule {
    quartz_cron_expression = "0 0 2 * * ?"
    timezone_id            = "UTC"
    pause_status           = "UNPAUSED"
  }

  email_notifications {
    on_failure = ["data-engineering@retail.example.com"]
  }

  job_cluster {
    job_cluster_key = "job_cluster"
    new_cluster {
      spark_version  = "14.3.x-photon-scala2.12"
      node_type_id   = "Standard_D4as_v5"
      spark_conf = {
        "spark.sql.adaptive.enabled" = "true"
        "spark.databricks.delta.optimizeWrite.enabled" = "true"
        "spark.databricks.delta.autoCompact.enabled"   = "true"
      }
      autoscale {
        min_workers = 1
        max_workers = 2
      }
      azure_attributes {
        availability = "ON_DEMAND_AZURE"
      }
    }
  }

  task {
    task_key     = "ingest_raw_orders"
    max_retries  = 0
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/raw/01_ingest_orders_api"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 1800
  }

  task {
    task_key     = "ingest_raw_customers"
    max_retries  = 0
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/raw/02_ingest_customers_api"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 1800
  }

  task {
    task_key    = "bronze_orders"
    max_retries = 0
    depends_on { task_key = "ingest_raw_orders" }
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/bronze/01_bronze_orders"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 3600
  }

  task {
    task_key    = "bronze_customers"
    max_retries = 0
    depends_on { task_key = "ingest_raw_customers" }
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/bronze/02_bronze_customers"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 3600
  }

  task {
    task_key    = "silver_orders"
    max_retries = 0
    depends_on { task_key = "bronze_orders" }
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/silver/01_silver_orders"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 3600
  }

  task {
    task_key    = "silver_customers"
    max_retries = 0
    depends_on { task_key = "bronze_customers" }
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/silver/02_silver_customers"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 3600
  }

  task {
    task_key    = "gold_fact_orders"
    max_retries = 0
    depends_on { task_key = "silver_orders" }
    depends_on { task_key = "silver_customers" }
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/gold/01_gold_fact_orders"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 3600
  }

  task {
    task_key    = "gold_dim_customer"
    max_retries = 0
    depends_on { task_key = "silver_customers" }
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/gold/03_gold_dim_customer_scd2"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 3600
  }

  task {
    task_key    = "gold_daily_revenue"
    max_retries = 0
    depends_on { task_key = "gold_fact_orders" }
    notebook_task {
      notebook_path = "/Workspace/Repos/retailflow/databricks/notebooks/gold/05_gold_daily_revenue_mart"
      source        = "WORKSPACE"
    }
    job_cluster_key = "job_cluster"
    timeout_seconds = 1800
  }

  tags = merge(var.tags, { "project" = "RetailFlow", "layer" = "platform" })
}
