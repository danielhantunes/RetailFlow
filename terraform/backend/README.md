# Terraform state backend bootstrap

The Terraform remote state backend is provisioned via **GitHub Actions using OIDC** (no Azure client secret). Run this **once per environment** (before using the main Terraform root) to create the Azure storage used for remote state. **Default Azure region for RetailFlow: East US 2.**

Creates the Azure resources used as Terraform remote state backend:

- **Resource group** — `{name_prefix}-tfstate-rg`
- **Storage account** — `{name_prefix}tfstate` (hyphens removed), with **blob versioning** enabled
- **Private container** — `tfstate` (or custom), no public access

## Separate backends for dev and prod (recommended)

Use a **separate state backend for production** to isolate blast radius, access control, and compliance:

| Environment | Run workflow with `name_prefix` | Storage account created | State key (main Terraform) |
|-------------|---------------------------------|--------------------------|----------------------------|
| **Dev**     | `retailflow-dev`                | `retailflowdevtfstate`   | `retailflow-dev.tfstate`   |
| **Prod**    | `retailflow-prod`               | `retailflowprodtfstate`  | `retailflow-prod.tfstate`  |

1. Run **Provision Terraform State Backend (Dev)** workflow (creates dev backend `retailflowdevtfstate`).
2. Run **Provision Terraform State Backend (Prod)** workflow (creates prod backend `retailflowprodtfstate`).
3. When running main Terraform, pass backend config at init (e.g. from the workflow output `terraform output backend_config`, or set `resource_group_name`, `storage_account_name`, `container_name`, and `key` per environment: dev key `retailflow-dev.tfstate`, prod key `retailflow-prod.tfstate`).

## Provisioning via GitHub Actions (OIDC)

1. **Azure federated identity**  
   In Azure Portal: **Microsoft Entra ID** → **App registrations** (or **Managed identities** → user-assigned) → your app/identity → **Certificates & secrets** → **Federated credentials** → Add. Create a **federated credential** with:
   - Issuer: `https://token.actions.githubusercontent.com`
   - Subject: `repo:<org>/<repo>:ref:refs/heads/main` (or `environment:<env>` for environment-specific)
   - Audience: `api://AzureADTokenExchange`

2. **GitHub secrets** (no client secret):
   - `AZURE_CLIENT_ID` — Application (client) ID
   - `AZURE_TENANT_ID` — Directory (tenant) ID
   - `AZURE_SUBSCRIPTION_ID` — Subscription ID

3. **Permissions**  
   Grant the app/managed identity **Contributor** (or at least resource group + storage account creation) on the subscription or a dedicated “bootstrap” resource group.

4. **Run the workflow**  
   - **Dev:** GitHub → **Actions** → **Provision Terraform State Backend (Dev)** (`provision-tfstate-dev.yml`) → **Run workflow**. Optional inputs: `azure_region`, `container_name`.
   - **Prod:** GitHub → **Actions** → **Provision Terraform State Backend (Prod)** (`provision-tfstate-prod.yml`) → **Run workflow** when you need a separate prod state backend.

## Local run (optional)

```bash
cd terraform/backend
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform plan
terraform apply
```

State for this bootstrap is stored locally by default. After the backend exists, configure the main Terraform root to use the azurerm backend: run `terraform output backend_config` and use that snippet (set `key` to `retailflow-dev.tfstate` or `retailflow-prod.tfstate` per environment), or pass `-backend-config=...` at init.

## Troubleshooting

If the workflow fails with **404 (ParentResourceNotFound)** when creating the storage account, Azure may have created the resource group and storage account but Terraform failed on a follow-up read (eventual consistency). **Re-run the workflow** once or twice; the second run often succeeds. If the resource group and storage account exist but the **tfstate** container does not, create the container manually: Storage account → **Containers** → **+ Container** → name **tfstate**. Then Terraform Platform (Dev) and Databricks (Dev) can use the backend; no need to re-run the state backend workflow.
