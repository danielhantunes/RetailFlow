# Azure Bastion — On-demand Browser SSH

Use Azure Bastion to connect to the **private** bootstrap VM (`retailflow-dev-bootstrap-vm`) without exposing SSH on the public internet. Bastion is deployed in its own Terraform layer so you can **destroy it when idle** to save hourly cost.

This document explains *how to connect* and *what credentials to use* for this project.

## 1. When to use Bastion in this project

- **Olist VM runner setup/debugging** (e.g. troubleshooting `register_only`/`bootstrap_only`)
- **Ad-hoc inspection** of the bootstrap VM (psql, Python toolbox scripts)

Ongoing Postgres → ADLS RAW ingestion is handled by the **Azure Function**, not by the VM.

## 2. Prerequisites

1. Terraform **Base (Dev)** has been applied (creates the VNet + the private bootstrap VM).
2. Terraform **Bastion (Dev)** has been applied (creates `AzureBastionSubnet` + Bastion + public IP).
3. For Microsoft Entra ID login on the VM:
   - Base layer has `AADSSHLoginForLinux` extension enabled (default),
   - Your Entra user is granted VM login role via Bastion workflow input `aad_admin_object_id`,
   - Bastion SKU is set to `Standard` (recommended for Entra login flow in Portal).

## 3. Connect via the Azure Portal (browser SSH)

1. In Azure Portal, open the VM resource (bootstrap VM).
2. Click **Connect**.
3. Select **Bastion** and then choose **SSH**.
4. Authenticate using the credentials described below.

## 4. Authentication options

Bastion **does not create** VM users or passwords. You connect using the VM’s configured admin access.

### Case A: Microsoft Entra ID (passwordless/keyless on VM)

- In Bastion connect, select **Microsoft Entra ID** authentication (when available for your Bastion SKU/flow).
- Sign in with your Entra account.
- Ensure your account has VM role assignment (`Virtual Machine Administrator Login` or `Virtual Machine User Login`).

### Case B: VM uses password authentication

- **Username:** `bootstrap_vm_admin_username` (default: `azureuser`)
- **Password:** `bootstrap_vm_admin_password` output from `terraform/base` (unless your VM was configured as key-only)

### Case C: VM uses SSH key authentication (key-only)

- Set `bootstrap_vm_ssh_public_key` during Terraform Base provisioning.
- In that case, the VM **password login is disabled**.
- Choose the **SSH key** option in the Bastion connect UI and upload/paste the **matching SSH private key**.

## 5. Cost control: destroy when you’re done

After you finish connecting/inspecting:

- Run **Terraform Bastion (Dev)** workflow with `action: destroy` (`terraform-bastion-dev.yml`).

Your other layers (Postgres, Azure Function, Databricks) continue to run; only Bastion is removed.

