# Observability

- **Logging:** Use structured logs in notebooks (JSON); send to Azure Log Analytics via agent or REST.
- **Job monitoring:** Databricks Jobs UI + email on failure; optional: log run metadata to Delta or Azure Monitor (see `databricks/notebooks/observability/job_monitor.py`).
- **Alerts:** Configure failure alerts in Databricks (email/Slack); Azure Monitor alerts on metric thresholds if needed.
- **Data quality:** DLT expectations (see `dlt/pipelines/bronze_silver_dlt.py`); optional Great Expectations or custom checks in notebooks.
