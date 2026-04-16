# Provisioning the Lab Environment

> **⚠ Workshop attendees: you do not need anything in this directory.**
>
> All lab provisioning is handled by your instructor before workshop day. You walk in to a fully-built lab and start at section 1.4 by SSHing into a pre-provisioned control node.
>
> This directory exists for two audiences:
>
> 1. **Future workshop instructors** who want to run this workshop themselves
> 2. **Anyone reproducing the lab on their own time** after the workshop, for practice or homelab use
>
> If you are a workshop attendee on workshop day, close this README and look at `LAB-OVERVIEW.md` instead.

---

The workshop's lab environment is three (sometimes four) virtual machines per attendee:

- `control` — Ubuntu 22.04, public IP, Ansible installed, the only host attendees SSH directly to
- `web1` — Ubuntu 22.04, private IP, target for sections 1.4 / 2.1 / 2.2 / 3.1 / 3.3
- `mgmt1` — Windows Server 2022 Datacenter (Desktop Experience), private IP, target for sections 2.3 / 3.1
- `web2` — added during section 3.3 for the rolling deploy demo

This directory contains **three different ways to provision that lab**, each appropriate for a different situation.

## The three paths

| Path | When to use it | Subdirectory |
|---|---|---|
| **Azure (Ansible)** | Workshop day, primary path. Provisions all attendee labs in Azure with one command. | `azure/` |
| **Azure (Bicep)** | Workshop day, backup path. Same lab, deployed via Bicep instead of Ansible — used if the Ansible Azure modules misbehave or if Mike/Joe wants to deploy from a Windows admin's natural toolchain. | `bicep/` |
| **Vagrant (local)** | After the workshop, on your own laptop. Lets you recreate the lab without an Azure subscription. | `vagrant/` |

## Which path runs the workshop?

**Azure (Ansible) is the primary path.** All other paths are alternatives.

The reasoning: the workshop is Ansible-first by design, so using Ansible to provision the workshop's own infrastructure is appropriately meta and dogfoods the tool attendees are about to learn. It also means there's exactly one tool (Ansible) in the repo that instructors need to be fluent with on workshop day.

The Bicep path exists as a backup for two reasons:

1. **The `azure.azcollection` Ansible modules occasionally have bugs** when Azure changes APIs, and you don't want to discover that at 6 AM on workshop day. Bicep gets the same job done with a different toolchain.
2. **Mike and Joe both speak Microsoft natively.** If something goes wrong with the Ansible path during the lab build, they should be able to fall through to Bicep without learning a third tool.

The Vagrant path is for attendees who want to take the workshop home. It runs against VirtualBox on a laptop, with no cloud subscription required.

## Prerequisites

### For the Azure paths (Ansible or Bicep)

- An Azure subscription with available credit (this workshop budgets ~$1000 for 20 attendees, regional `westus2`)
- The Azure CLI installed and logged in (`az login`)
- For the Ansible path: Python 3.10+, the `azure.azcollection` Galaxy collection installed (the playbook handles this in pre-tasks)
- For the Bicep path: Bicep CLI (bundled with recent versions of `az`)

### For the Vagrant path

- VirtualBox 7.x
- Vagrant 2.4+
- ~30 GB free disk space (the Windows Server 2022 box is large)
- ~16 GB RAM on the host machine (the lab uses ~8 GB at peak)

## The provisioning protocol on workshop day

This is the rough timeline for an instructor running the workshop:

| When | Action |
|---|---|
| ~1 week before | Edit `azure/inventory/attendees.yml` with the final attendee count and any per-attendee customizations |
| ~1 week before | Run `azure/site.yml` to provision all attendee labs |
| ~1 week before | Run the lab build / capture pass against one attendee's lab (see `docs/captures/HOW-TO-CAPTURE.md`) |
| Day before | Verify all attendee labs are still reachable: `ansible-playbook azure/verify.yml` |
| Day before | Generate and print the attendee credentials cards from `azure/attendee-credentials.csv` |
| Workshop day | Hand out cards at the door |
| After workshop | Run `azure/teardown.yml` to delete every resource group and avoid surprise bills |

See each subdirectory's own README for the specific commands.

## Cost considerations

The workshop is budgeted for ~$1000 of Azure credit, sized for 20 attendees over a single workshop day. The actual cost is much lower than that — the lab budget is ~$15-25 per attendee per workshop day for compute, but the budget includes headroom for:

- Instructor lab build / capture pass runs (1-2 days of one attendee lab)
- Last-minute re-provisioning if something breaks
- An extra ~5 attendees showing up unregistered
- The labs running for ~6 hours instead of 4 (workshop overruns happen)

The single most important cost-control discipline is **running the teardown playbook on the same day as the workshop**. Forgetting to tear down can turn a $300 workshop into a $1500 surprise bill. The runbook (`docs/runbook.md`) has this on the day-of checklist.
