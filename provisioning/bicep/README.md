# Azure Provisioning (Bicep) — Backup Path

> **This is the backup provisioning path.** The primary path is Ansible-driven (`provisioning/azure/`). Use Bicep only if the Ansible Azure modules are misbehaving on workshop day, or if you (Mike or Joe) prefer Bicep for any reason.

## Why this path exists

Two reasons:

1. **The `azure.azcollection` Ansible modules occasionally have bugs.** Azure changes APIs, the collection lags, and you don't want to discover that at 6 AM on workshop day. Bicep is Microsoft-native and tracks Azure API changes immediately.
2. **You both speak Microsoft natively.** If something goes wrong with the Ansible path, this is the toolchain you can fall through to without learning anything new.

## What it builds

Exactly the same lab as the Ansible path: per attendee, a resource group with a vnet, NSG, control node, web1, mgmt1, and the WinRM bootstrap on the Windows host.

## Files

| File | Purpose |
|---|---|
| `main.bicep` | The Bicep template that builds one attendee's lab |
| `parameters.example.json` | Template for the parameters file you pass to `az deployment` |
| `deploy-all.sh` | Shell script that loops over attendees and calls `az deployment group create` for each |
| `teardown.sh` | Shell script that deletes every workshop resource group |

The `main.bicep` template is intentionally a single file, not modules. For a workshop lab where readability matters more than reusability, one file you can read top-to-bottom is better than seven you have to navigate.

## Usage

### One-time setup

```bash
# Bicep CLI is bundled with recent Azure CLI versions
az bicep version

# If not installed:
az bicep install

# Log in to Azure
az login
az account set --subscription "<subscription-id-or-name>"
```

### Provision all attendees

```bash
# Edit deploy-all.sh and set the attendee count and any per-workshop variables
$EDITOR deploy-all.sh

# Run it
./deploy-all.sh

# Output: each attendee's resource group is created, and the public IPs are
# printed at the end. The script also generates attendee-credentials.csv
# in the same format as the Ansible path produces.
```

### Provision one attendee (for testing)

```bash
# Create a parameters file from the example
cp parameters.example.json parameters-test.json
$EDITOR parameters-test.json

# Deploy
RG="workshop-att-99-rg"
az group create --name "$RG" --location westus2
az deployment group create \
    --resource-group "$RG" \
    --template-file main.bicep \
    --parameters @parameters-test.json
```

### Tear down

```bash
./teardown.sh
```

## Differences from the Ansible path

| Aspect | Ansible path | Bicep path |
|---|---|---|
| Per-attendee provisioning time | ~10-15 min (parallelized) | ~8-12 min (Azure handles parallelism) |
| Idempotency | Native | Native (Bicep deployments are declarative) |
| Credential generation | Ansible `lookup('password')` | Shell `openssl rand` in deploy-all.sh |
| Credentials CSV format | Identical | Identical |
| Verify step | `verify.yml` | `verify.sh` (calls `az` and SSH) |
| Cloud-init for control node | Inline in role template | External file referenced in main.bicep |
| WinRM bootstrap script | Same `winrm-bootstrap.ps1` referenced from the Ansible path | Same script, same URL |

The two paths share the WinRM bootstrap script and the cloud-init file. Don't fork them — if you need to update one, update both.
