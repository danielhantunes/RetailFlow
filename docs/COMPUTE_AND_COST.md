# Compute environments and cost

RetailFlow uses two compute environments to simulate production-grade architecture while keeping cost low. Use the **same Azure region** for both.

---

## DEV environment

| Setting | Value |
|--------|--------|
| **Cluster type** | Single-node cluster |
| **Driver node** | Standard_D4as_v5 (or similar small instance) |
| **Workers** | 0 |
| **Spark runtime** | Databricks Runtime LTS |
| **Photon** | Disabled (to reduce cost) |
| **Autoscaling** | Disabled |
| **Auto termination** | 30 minutes |
| **Typical usage** | ~1 hour per day, ~20 days per month |
| **Estimated monthly runtime** | ~20 hours |
| **Goal** | Keep development compute around **$10–15/month** |

### Why these choices

- **Single-node clusters** are common in dev because workloads use small sample data; one node is enough and avoids the cost of extra workers while still running the same code path as production.
- **Autoscaling is not needed** in development: workloads are small and predictable, so a fixed single node keeps cost predictable and avoids accidental scale-out.
- **Auto-termination is critical**: without it, clusters stay on and accrue DBU and VM cost. Thirty minutes idle is a good balance so you don’t leave clusters running overnight or over the weekend.

**Cost tip:** Use a **single-node job cluster** for dev runs (e.g. triggered from a job or Airflow) rather than a long-lived all-purpose cluster, so you only pay for actual runtime and stay within the $10–15/month target.

---

## PROD environment (pipeline jobs)

| Setting | Value |
|--------|--------|
| **Cluster type** | Jobs cluster (not all-purpose) |
| **Driver node** | Standard_D4as_v5 |
| **Workers** | 1 minimum |
| **Autoscaling** | 1–2 workers |
| **Spark runtime** | Databricks Runtime LTS |
| **Photon** | Enabled (recommended) |
| **Cluster lifecycle** | Terminates automatically after the job finishes |
| **Typical usage** | 2 runs per day, ~10 minutes per run |
| **Estimated monthly runtime** | ~10 hours |
| **Goal** | Keep production compute around **$5–10/month** |

### Why these choices

- **Job clusters are cheaper than all-purpose** because they use the jobs DBU rate and only run for the duration of the job; there is no idle time between runs.
- **Small autoscaling (1–2 workers)** is enough for this batch pipeline; it adds a bit of parallelism for shuffles and joins without over-provisioning.
- **Terminate after job** ensures you only pay for the actual run time (~10 min × 2 × 30 days ≈ 10 hours/month). If the cluster stayed up between runs, you’d pay for 24/7 uptime.

The main pipeline job is defined in Terraform (`terraform/databricks/databricks_resources.tf`) and uses this style of job cluster.

---

## Total monthly cost (ballpark)

| Component | Range |
|-----------|--------|
| Databricks DEV (single-node, ~20 hrs) | $10–15 |
| Databricks PROD (job cluster, ~10 hrs) | $5–10 |
| Azure (ADLS, VNet, Key Vault, tfstate, private endpoint) | $15–40 |
| Snowflake (if used; light BI) | $0–50+ |
| **Total (without Snowflake)** | **~$30–65/month** |
| **With light Snowflake** | **~$30–115/month** |

A **~$50/month** midpoint for Azure + Databricks is a reasonable estimate; add Snowflake if you use it for gold serving.

---

## Reducing cost: plan and destroy

- **Terraform plan** does not create resources; cost is negligible.
- **After destroying resources**, you stop paying for them. Destroy **Databricks** (Terraform Databricks layer) to eliminate Databricks cost (~$15–25/month). Destroy **base** as well to remove ADLS, VNet, Key Vault, etc.
- The only remaining cost after a full destroy is usually the **Terraform state backend** (storage account for tfstate) if you keep it for future runs—typically **$1–5/month**. Destroy that too for **$0**.

**Destroy order:** Run Terraform Databricks (Dev) with `action: destroy` first, then Terraform Base (Dev) with `action: destroy`. See [README — CI/CD](../README.md#cicd-github-actions).
