# Checkpoint: End of Section 2.1

This directory is a complete, runnable snapshot of the workshop repo as it should look at the end of section 2.1. If you got lost during the section and want to catch up before 2.2 starts:

```bash
cd ~/workshop/checkpoints/section-2.1
ansible-playbook playbooks/02-web-tier.yml
```

That will run the section 2.1 playbook against your lab's web1 host using the checkpoint's known-good copy of all files. nginx will be installed (or already installed), the Jinja2-templated status page will be deployed, and `http://localhost:8080` should show the branch office page.

After confirming it works, you have two options:

1. **Continue from inside the checkpoint directory** for the rest of the workshop. The relative paths in the playbooks (`../templates/...`) work just as well from here as they do from `~/workshop/`.
2. **Copy the files back to `~/workshop/`** to continue from there:
   ```bash
   cp playbooks/01-hello-world.yml ~/workshop/playbooks/
   cp playbooks/02-web-tier.yml ~/workshop/playbooks/
   cp templates/status.html.j2 ~/workshop/templates/
   cp templates/nginx-site.conf.j2 ~/workshop/templates/
   ```

Either way works.

## What's in this checkpoint

```
ansible.cfg                              ← workshop config
inventory/hosts.yml                      ← workshop inventory
inventory/group_vars/all.yml             ← shared variables (branch_id, etc.)
inventory/group_vars/linux.yml           ← Linux SSH connection vars
inventory/group_vars/windows.yml         ← Windows WinRM vars (still has placeholder)
playbooks/01-hello-world.yml             ← the trivial first playbook
playbooks/02-web-tier.yml                ← the nginx + status page playbook
templates/status.html.j2                 ← the Jinja2 status page template
templates/nginx-site.conf.j2             ← the nginx site config template
```

> **Note:** `inventory/group_vars/windows.yml` in this checkpoint still has the Windows password placeholder. If you want to use the checkpoint to recover during the workshop, you'll need to put your Windows password in there too (just like you did in section 1.4 step 4). The checkpoint can't ship with a real password because the password is unique per attendee.
