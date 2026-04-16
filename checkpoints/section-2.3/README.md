# Checkpoint: End of Section 2.3

Complete, runnable snapshot of the workshop repo as it should look at the end of section 2.3. New since the section 2.2 checkpoint:

- `roles/windows-mgmt/` — the new Windows automation role
- `playbooks/04-windows-mgmt.yml` — the playbook that runs it

If you got lost during the section and want to catch up before section 3.1 starts:

```bash
cd ~/workshop/checkpoints/section-2.3
ansible-playbook playbooks/04-windows-mgmt.yml
```

That will run the role against your lab's mgmt1 host. On a system that already had section 2.3 applied, the run will be all `ok`/skipped and complete in under a minute. On a clean mgmt1, the first run takes 5-10 minutes (Chocolatey downloads).

> **Note on the Windows password placeholder:** the checkpoint's `inventory/group_vars/windows.yml` still has the password placeholder. You need to put your Windows admin password (from your card) in there before any Windows-targeting playbook will work — same as section 1.4 step 4.
