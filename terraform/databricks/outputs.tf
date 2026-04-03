output "workspace_url" {
  description = "Databricks workspace URL (from remote state)"
  value       = local.databricks_host
}

output "workspace_id" {
  description = "Azure workspace resource ID (from remote state)"
  value       = local.databricks_workspace_resource_id
}

output "job_id" {
  description = "RetailFlow_Main_Pipeline job ID"
  value       = databricks_job.main_pipeline.id
}

output "dev_cluster_id" {
  description = "Dev single-node cluster ID"
  value       = databricks_cluster.dev.id
}
