# Azure Provisioning (Ansible)

The primary path for provisioning workshop labs in Azure. This directory contains an Ansible playbook that creates one resource group per attendee, each containing a control node, a Linux web host, and a Windows management host.

## What this builds

Per attendee:

```
Resource Group: workshop-att-NN-rg     (e.g., workshop-att-01-rg)
├── Virtual Network                    10.NN.0.0/16
│   └── Subnet "lab"                   10.NN.0.0/24
├── Network Security Group             allows SSH from conference IPs only
├── Public IP                          attached only to the control node
├── VM: control                        Ubuntu 22.04 LTS, Standard_B2s
│   ├── /home/attendee/workshop        repo cloned at first boot
│   ├── ansible installed              via cloud-init
│   ├── pywinrm installed              for Windows targets
│   └── SSH key + password auth        password from attendee-credentials.csv
├── VM: web1                           Ubuntu 22.04 LTS, Standard_B2s, no public IP
└── VM: mgmt1                          Windows Server 2022 Datacenter (Desktop Experience), Standard_B2ms, no public IP
    └── WinRM bootstrapped             via custom script extension on first boot
```

The `web2` host (for the section 3.3 rolling deploy demo) is **not** provisioned up front. It's added mid-workshop by a small companion playbook attendees run themselves. This keeps the initial provisioning fast and the resource cost lower for sections 1-2.

## Files in this directory

| File | Purpose |
|---|---|
| `site.yml` | The master playbook. Runs `provision.yml` for every attendee, then writes the credentials CSV. |
| `provision.yml` | Provisions one attendee's complete lab environment. Called once per attendee from `site.yml`. |
| `verify.yml` | Day-before sanity check. Connects to every attendee's control node and verifies SSH + WinRM both work. |
| `teardown.yml` | Deletes every attendee resource group. Run after the workshop to stop the meter. |
| `inventory/attendees.yml` | The attendee list. Edit this before running `site.yml`. |
| `group_vars/all.yml` | Global settings: Azure region, VM SKUs, image references, naming conventions. |
| `roles/attendee-rg/` | The role that builds one attendee's lab. Used by `provision.yml`. |
| `files/winrm-bootstrap.ps1` | First-boot script for the Windows VM. Configures WinRM, opens the firewall, sets the local password. |
| `files/cloud-init-control.yml` | First-boot config for the Linux control node. Installs Ansible, pywinrm, clones the workshop repo. |

## Prerequisites

### One-time setup

```bash
# Install the Azure collection
ansible-galaxy collection install azure.azcollection

# Install the Python SDK dependencies the collection needs
pip install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements.txt

# Log in to Azure
az login

# Confirm you're using the right subscription
az account show
az account set --subscription "<subscription-id-or-name>"
```

### Per-workshop setup

1. **Edit `inventory/attendees.yml`** with the final attendee count.
2. **Edit `group_vars/all.yml`** if you need to override the default region (`westus2`), VM sizes, or naming.
3. **Optional but recommended:** create a service principal for non-interactive runs:
   ```bash
   az ad sp create-for-rbac --name "ansible-workshop-sp" \
       --role Contributor \
       --scopes /subscriptions/<your-sub-id>
   ```
   Save the output to `~/.azure/credentials` in the format documented at https://docs.ansible.com/ansible/latest/collections/azure/azcollection/

## Workshop-week timeline

### One week before the workshop

```bash
# 1. Edit the attendee list
$EDITOR inventory/attendees.yml

# 2. Provision everyone (this takes ~10-15 min per attendee, runs 5 in parallel)
ansible-playbook site.yml

# 3. Verify the provisioning
ansible-playbook verify.yml

# 4. The credentials file is now at ./attendee-credentials.csv
# Print this. Lock it up. Treat it like a password file (because it is one).
cat attendee-credentials.csv
```

### Day before the workshop

```bash
# Verify everything is still healthy
ansible-playbook verify.yml

# If anything has drifted, re-run site.yml — it's idempotent and will only
# fix what's broken
ansible-playbook site.yml
```

### After the workshop

```bash
# Tear down EVERY attendee resource group. This is the most important step.
ansible-playbook teardown.yml

# Verify the teardown worked
az group list -o table | grep workshop-att   # should return nothing
```

## Common issues

### "The Azure SDK isn't installed"

Run the `pip install` command from the prerequisites section above. The `azure.azcollection` Galaxy collection has its own Python dependency requirements that don't get installed automatically.

### "Resource provider not registered"

Some Azure subscriptions need explicit registration of the compute provider:

```bash
az provider register --namespace Microsoft.Compute --wait
az provider register --namespace Microsoft.Network --wait
```

### "Quota exceeded for Standard_B series"

Default Azure subscriptions have low B-series quotas. If you're provisioning ~20 attendees and each needs 3 VMs, that's 60 VMs total — easily over the default 10-vCPU quota. Request a quota increase at https://portal.azure.com → Quotas. Ask for at least 100 vCPUs in the workshop region. Microsoft typically approves these within an hour for legitimate use.

### "Provisioning a single attendee works but `site.yml` is slow"

By default `site.yml` provisions 5 attendees in parallel (controlled by `forks` in the workshop's `ansible.cfg`). Bumping this to 10 cuts wall-clock time roughly in half but increases the chance of hitting Azure API rate limits. 5 is a good default.

### "I want to test against just one attendee"

```bash
# Provision a single attendee for testing (overrides the inventory)
ansible-playbook site.yml --limit attendee01

# Or use a special "test" attendee with a known number
ansible-playbook provision.yml -e "attendee_number=99" -e "purpose=capture-pass"
```

## What the credentials CSV looks like

After `site.yml` finishes, `attendee-credentials.csv` contains one row per attendee with everything needed to print a lab access card:

```csv
attendee_number,attendee_name,control_public_ip,ssh_username,ssh_password,vault_password
01,attendee01,20.42.123.45,attendee,K7p2vQ8mN3rL,workshop-vault-2026
02,attendee02,20.42.123.67,attendee,X9aB4tY1cR8w,workshop-vault-2026
...
```

The Vault password is the same for all attendees (it's the password printed on the Vault password card and posted on the slide during section 3.2). It's included here only so the credentials file is the single source of truth for printing cards.

**Treat `attendee-credentials.csv` as a secret.** It's in `.gitignore` and is never committed. Once the workshop is over and the labs are torn down, delete the file.
