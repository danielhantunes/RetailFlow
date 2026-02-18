"""
Create Databricks secret scope backed by Azure Key Vault.
Run from local with databricks-cli or from a bootstrap notebook.
"""
# Usage: set DATABRICKS_HOST, DATABRICKS_TOKEN; then run with key vault resource id and scope name.
# From notebook: dbutils.secrets.createScope("retailflow-keyvault", ...) or use Azure Key Vault-backed scope via UI.

def create_scope_from_keyvault(workspace_url: str, token: str, scope_name: str, kv_resource_id: str, kv_dns_name: str):
    import requests
    url = f"{workspace_url.rstrip('/')}/api/2.0/secrets/scopes/create"
    payload = {
        "scope": scope_name,
        "scope_backend_type": "AZURE_KEYVAULT",
        "backend_azure_keyvault": {
            "resource_id": kv_resource_id,
            "dns_name": kv_dns_name,
        },
    }
    resp = requests.post(url, headers={"Authorization": f"Bearer {token}"}, json=payload, timeout=30)
    resp.raise_for_status()
    return resp.json()
