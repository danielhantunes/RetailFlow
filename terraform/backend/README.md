# Terraform state backend bootstrap

Run this **once** (before using the main Terraform root) to create the Azure storage used for remote state. **Default Azure region for RetailFlow: East US.**

Creates the Azure resources used as Terraform remote state backend:

- **Resource group** — `{name_prefix}-tfstate-rg`
- **Storage account** — `{name_prefix}tfstate` (hyphens removed), with **blob versioning** enabled
- **Private container** — `tfstate` (or custom), no public access

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
   GitHub → **Actions** → **Provision Terraform State Backend** (`provision-tfstate.yml`) → **Run workflow**. Use inputs for `name_prefix`, `azure_region`, `container_name`.

## Local run (optional)

```bash
cd terraform/backend
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform plan
terraform apply
```

State for this bootstrap is stored locally by default. After the backend exists, configure the main Terraform root to use the azurerm backend (see `terraform output backend_config`).
