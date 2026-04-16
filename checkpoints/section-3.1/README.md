# Checkpoint: End of Section 3.1

Complete, runnable snapshot of the workshop repo as it should look at the end of section 3.1. New since the section 2.3 checkpoint:

- `roles/hardening/` — the cross-platform hardening role (dispatcher + linux.yml + windows.yml)
- `playbooks/05-harden.yml` — the playbook that runs it across the `branch_office` group

If you got lost during the section and want to catch up before section 3.2 starts:

```bash
cd ~/workshop/checkpoints/section-3.1
ansible-playbook playbooks/05-harden.yml
```

> **Note on the Windows password placeholder:** as with all checkpoints, `inventory/group_vars/windows.yml` has the placeholder. Put your Windows password from your card in there before running.
