# Checkpoint: End of Section 2.2

This directory is a complete, runnable snapshot of the workshop repo as it should look at the end of section 2.2. The new addition compared to the section 2.1 checkpoint is the `roles/webserver/` directory and the `playbooks/03-web-tier-with-roles.yml` playbook.

If you got lost during the section and want to catch up before 2.3 starts:

```bash
cd ~/workshop/checkpoints/section-2.2
ansible-playbook playbooks/03-web-tier-with-roles.yml
```

That will run the role against your lab from a known-good copy. nginx will already be installed (from section 2.1), the role will just confirm everything is in the desired state, and the page at `http://localhost:8080` will serve the templated branch office page.

## What's new compared to section-2.1

- `roles/webserver/` — the role version of the section 2.1 web tier playbook
- `playbooks/03-web-tier-with-roles.yml` — the 10-line playbook that uses the role

Everything else is identical to section-2.1. The section 2.1 playbook (`02-web-tier.yml`) is preserved here so you can compare the two side by side.

> **Note on the Windows password placeholder:** as with all checkpoints, `inventory/group_vars/windows.yml` still has the `REPLACE_ME_WITH_PASSWORD_FROM_YOUR_CARD` placeholder. If you copy this checkpoint over your `~/workshop` to recover, you'll need to put your Windows password in there again (just like section 1.4 step 4).
