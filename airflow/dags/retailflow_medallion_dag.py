"""
RetailFlow Medallion DAG: RAW → Bronze → Silver → Gold
Orchestrates Databricks jobs via DatabricksSubmitRunOperator.
Requires: apache-airflow-providers-databricks, connection id 'databricks_default'.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.databricks.operators.databricks import DatabricksSubmitRunOperator

ENV = "dev"
JOB_ID = 1  # Set to your deployed Databricks job ID, or use RunNow with job_id

default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "email_on_failure": True,
    "email": ["data-engineering@retail.example.com"],
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="retailflow_medallion",
    default_args=default_args,
    description="RetailFlow full medallion pipeline on Databricks",
    schedule_interval="0 2 * * *",  # 02:00 UTC daily
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["retailflow", "medallion"],
) as dag:
    run_retailflow_job = DatabricksSubmitRunOperator(
        task_id="run_retailflow_main_pipeline",
        databricks_conn_id="databricks_default",
        json={
            "job_id": JOB_ID,
            "python_params": [],
            "notebook_params": {},
            "jar_params": [],
            "spark_submit_params": [],
            "polling_period_seconds": 30,
        },
    )
