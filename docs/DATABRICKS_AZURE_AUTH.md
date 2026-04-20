# Databricks authentication with Azure AD (Service Principal)

**Terraform Databricks Workspace (Dev)** and **Terraform Databricks (Dev)** use the **same** Azure AD Service Principal you already use for Terraform (Azure RM), with **OIDC only** (no client secret). The Databricks Terraform provider uses **azure-cli** auth, so it uses the credential established by the `azure/login` step (OIDC). Access to the workspace is **automated via Terraform** in the workspace stack: Terraform grants **Contributor** on the workspace resource to the SP, and identities with Contributor or Owner on the workspace resource in Azure automatically get workspace admin permission when accessing Databricks (including the API). You do not need to add the app to the workspace manually, even when running apply/destroy frequently. The workspace workflow provisions workspace resources only; Unity Catalog is managed separately.

## Steps

### 1. Service Principal in Azure (App Registration)

If you already use OIDC for Terraform Azure, you likely have an **App Registration** in Azure AD (Entra ID) with:

- **Federated credential** for GitHub Actions (issuer `https://token.actions.githubusercontent.com`, subject for your repo).
- That app is used as `AZURE_CLIENT_ID` in GitHub secrets.

For **Databricks**, the Terraform provider uses **azure-cli** authentication, so it uses the same OIDC credential from the `azure/login` step. **No client secret** is required.

- Note: **Application (client) ID** and **Directory (tenant) ID** (already used as `AZURE_CLIENT_ID` and `AZURE_TENANT_ID`).
- For the workspace role assignment, you need the **Object ID** of the **Service Principal** (the Enterprise Application linked to the app): **Microsoft Entra ID** → **Enterprise applications** → find the app by name → **Object ID**. This value is the secret **`AZURE_PRINCIPAL_ID`**.

### 2. Workspace access (automated via Terraform)

The **workspace** stack (`terraform/databricks_workspace`) includes an **`azurerm_role_assignment`** that grants the SP (using `azure_principal_id`) the **Contributor** role on the workspace resource. In Azure Databricks, identities with Contributor or Owner on the workspace resource automatically get workspace admin permission when accessing the workspace (including API calls). After **Terraform Databricks Workspace (Dev)** apply:

1. The workspace is created.
2. Terraform assigns Contributor on the workspace to that SP.

The **compute** stack (`terraform/databricks`) runs **after** the workspace stack. It reads `workspace_url` / `workspace_id` from the workspace remote state and uses a **single** `terraform apply` to create the dev cluster and job—no second apply and no manual `DATABRICKS_HOST` secrets.

Destroying **Terraform Databricks (Dev)** removes job and cluster only; the workspace and role assignment remain until you destroy **Terraform Databricks Workspace (Dev)**. Destroying the workspace stack removes the role assignment with the workspace. Nothing needs to be done manually in Databricks for routine apply/destroy of compute.

### 3. GitHub secrets

Under **Settings** → **Secrets and variables** → **Actions**, configure:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Application (client) ID of the app in Azure AD (already used by Terraform Azure RM and azure/login). |
| `AZURE_TENANT_ID` | Directory (tenant) ID (already used by Terraform Azure RM and azure/login). |
| `AZURE_PRINCIPAL_ID` | **Object ID** of the Service Principal (Enterprise Application) of the same app. Used by Terraform to create the role assignment (Contributor on the workspace). |

**No `ARM_CLIENT_SECRET`** is needed; the Databricks provider uses **azure-cli** auth and the credential from the `azure/login` (OIDC) step.

The workflow passes `AZURE_PRINCIPAL_ID` as `TF_VAR_azure_principal_id`. If this secret is not set, the role assignment will not be created and you must grant the SP access by other means (e.g. manually).

**Permission to create the role assignment:** The Service Principal that runs Terraform (the same `AZURE_CLIENT_ID`) must have permission to create role assignments on the workspace scope (e.g. **Owner** or **User Access Administrator** on the resource group or subscription). **Contributor** on the resource group alone is not enough to create role assignments.

### 4. Workflow behavior

- **Terraform Databricks Workspace (Dev):** One `apply` creates the workspace and the Contributor role assignment for the SP (when `AZURE_PRINCIPAL_ID` is set).
- **Terraform Databricks (Dev):** One `apply` creates the dev cluster and main job; it loads workspace connection details from **remote state** (`retailflow-dev-databricks-workspace.tfstate` by default), not from a second apply.
- **Unity Catalog:** not managed by `terraform-databricks-workspace-dev.yml`; configure in Databricks (or use `terraform/databricks_unity_catalog` separately if you want IaC for UC).
- **Destroy compute only:** **Terraform Databricks (Dev)** `destroy` removes the job and clusters; notebooks and the workspace stay.
- **Destroy workspace:** **Terraform Databricks Workspace (Dev)** `destroy` removes the workspace (and its role assignments); run **after** compute destroy or when you accept losing the workspace.

You do not need to set `DATABRICKS_HOST` or `DATABRICKS_TOKEN` for these Terraform workflows; compute reads host and workspace ID from remote state and OIDC.

---

## Troubleshooting: 403 when creating the role assignment

If apply fails with:

`AuthorizationFailed ... does not have authorization to perform action 'Microsoft.Authorization/roleAssignments/write'`

the SP that runs Terraform **does not have permission to create role assignments**. **Contributor** on the resource group is not enough; you need **User Access Administrator** or **Owner**.

**Option A (recommended):** Grant the SP the **User Access Administrator** role on the resource group that contains the workspace (e.g. `retailflow-dev-rg`), or on the subscription. In Azure Portal: **Resource group** → **Access control (IAM)** → **Add role assignment** → Role: **User Access Administrator** → Members: select the app (e.g. github-retailflow-oidc). Then run the workflow again.

**Option B:** Do not use the role assignment in Terraform: remove the **`AZURE_PRINCIPAL_ID`** secret from the repo (or leave it empty). The workspace stack will not create the role assignment. Ensure the SP already has **Contributor** on the workspace resource (e.g. inherited from the RG or assigned manually once) so **Terraform Databricks (Dev)** (cluster/job) can authenticate.

---

## References

- [Authenticate with Microsoft Entra service principals - Azure Databricks](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/auth/azure-sp)
- [Workspace admins - Azure Databricks](https://learn.microsoft.com/en-us/azure/databricks/admin/admin-concepts#workspace-admins) (Contributor/Owner on the workspace resource)
- [Environment variables - Azure Databricks](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/auth/env-vars)
