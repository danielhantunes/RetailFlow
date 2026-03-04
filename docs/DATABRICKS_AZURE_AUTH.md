# Autenticação Databricks com Azure AD (Service Principal)

O workflow **Terraform Databricks (Dev)** usa o **mesmo** Service Principal do Azure AD que você já usa para o Terraform (Azure RM). O acesso do SP ao workspace é **automatizado via Terraform**: o Terraform concede **Contributor** no recurso do workspace ao SP, e quem tem Contributor no workspace no Azure recebe automaticamente permissão de workspace admin ao acessar o Databricks (incluindo API). Assim não é preciso adicionar o app manualmente no workspace, mesmo usando apply/destroy com frequência.

## Passos

### 1. Service Principal no Azure (App Registration)

Se você já usa OIDC para o Terraform Azure, provavelmente já tem um **App Registration** no Azure AD (Entra ID) com:

- **Federated credential** para GitHub Actions (issuer `https://token.actions.githubusercontent.com`, subject do repo).
- Esse app é usado como `AZURE_CLIENT_ID` nos secrets do GitHub.

Para o **Databricks**, o provider Terraform usa autenticação **azure-client-secret**. Então você precisa de um **client secret** para esse mesmo app.

- No **Azure Portal** → **Microsoft Entra ID** → **App registrations** → (seu app).
- **Certificates & secrets** → **New client secret** → copie o valor (só aparece uma vez).
- Anote: **Application (client) ID** e **Directory (tenant) ID** (já usados como `AZURE_CLIENT_ID` e `AZURE_TENANT_ID`).
- Para o role assignment no workspace, você precisa do **Object ID** do **Service Principal** (a “Enterprise Application” associada ao app): em **Microsoft Entra ID** → **Enterprise applications** → procure pelo nome do app → **Object ID**. Esse valor será o secret **`AZURE_PRINCIPAL_ID`**.

### 2. Acesso ao workspace (automático via Terraform)

O Terraform do layer Databricks inclui um **`azurerm_role_assignment`** que concede ao SP (usando o `azure_principal_id`) a role **Contributor** no recurso do workspace. No Azure Databricks, identidades com Contributor ou Owner no recurso do workspace recebem automaticamente permissão de workspace admin ao acessar o workspace (incluindo chamadas à API). Assim, após o primeiro apply:

1. O workspace é criado.
2. O Terraform atribui Contributor no workspace a esse SP.
3. O segundo apply já consegue autenticar com o mesmo SP e criar job e cluster, sem passo manual.

Em cada **destroy**, a role assignment é removida junto com o workspace. No **apply** seguinte, workspace e role assignment são criados de novo. Nada precisa ser feito manualmente no Databricks.

### 3. Secrets no GitHub

Em **Settings** → **Secrets and variables** → **Actions**, configure:

| Secret | Descrição |
|--------|-----------|
| `AZURE_CLIENT_ID` | Application (client) ID do app no Azure AD (já usado pelo Terraform Azure RM). |
| `AZURE_TENANT_ID` | Directory (tenant) ID (já usado pelo Terraform Azure RM). |
| `ARM_CLIENT_SECRET` | **Client secret** do mesmo app. Necessário para o provider Databricks (`azure-client-secret`). |
| `AZURE_PRINCIPAL_ID` | **Object ID** do Service Principal (Enterprise Application) do mesmo app. Usado pelo Terraform para criar a role assignment (Contributor no workspace). |

O workflow passa `AZURE_PRINCIPAL_ID` como `TF_VAR_azure_principal_id`. Se esse secret não estiver definido, a role assignment não será criada e será necessário conceder acesso ao SP por outro meio (por exemplo, manualmente).

**Permissão para criar a role assignment:** O Service Principal que executa o Terraform (o mesmo `AZURE_CLIENT_ID`) precisa ter permissão para criar role assignments no escopo do workspace (ex.: **Owner** ou **User Access Administrator** no resource group ou na subscription). Só **Contributor** no RG não basta para criar atribuições de role.

### 4. Comportamento do workflow

- **Apply:** O primeiro apply cria o workspace e a role assignment (Contributor para o SP). O workflow lê os outputs `workspace_url` e `workspace_id` e roda um segundo apply passando `TF_VAR_databricks_host` e `TF_VAR_databricks_workspace_resource_id`, criando o cluster de dev e o job.
- **Destroy:** O workflow lê os outputs do state e faz o destroy do job, do cluster, da role assignment e do workspace na ordem correta.

Não é necessário configurar `DATABRICKS_HOST` nem `DATABRICKS_TOKEN` nos secrets; o workflow obtém o host e o resource ID dos outputs do Terraform.

---

## Referências

- [Authenticate with Microsoft Entra service principals - Azure Databricks](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/auth/azure-sp)
- [Workspace admins - Azure Databricks](https://learn.microsoft.com/en-us/azure/databricks/admin/admin-concepts#workspace-admins) (Contributor/Owner no recurso do workspace)
- [Environment variables - Azure Databricks](https://learn.microsoft.com/en-us/azure/databricks/dev-tools/auth/env-vars)
