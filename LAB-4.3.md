# Section 4.3 — Capstone: Complete the Project

> **Duration:** 20 minutes
> **Presenters:** Joe + Mike (both on stage, alternating)
> **Your goal:** Run `playbooks/site.yml` — the single playbook that orchestrates everything you've built today — and watch your entire branch office come together in one command.

## Why this section exists

This is the moment everything ties together. You've built a Linux web tier (sections 2.1-2.2), a Windows management host (section 2.3), a cross-platform hardening role (section 3.1), encrypted secrets (section 3.2), and a rolling deployment pipeline (section 3.3). They're all real, they all work — but they've been separate playbooks running separately.

Real-world Ansible doesn't work that way. Real-world Ansible has a single `site.yml` at the top of the repo that orchestrates everything. When a new server comes online, you point `site.yml` at it and the entire stack — OS config, app, baseline, monitoring, everything — comes up in one command.

This section has you do that.

## What you'll do in this section

1. Look at `playbooks/site.yml` and understand its structure
2. Tear down a single component (delete nginx from web1) to prove the rebuild works
3. Run `site.yml` and watch the entire lab rebuild itself
4. Verify the end state — both web servers serve the templated page, mgmt1 is configured, hardening is applied
5. Deliberately break web1 with a manual config change, re-run `site.yml`, watch Ansible correct the drift
6. Discussion: where you go from here in real-world Ansible

## Step 1 — Look at site.yml

```bash
cd ~/workshop
cat playbooks/site.yml
```

It's three plays in sequence:

```yaml
- name: "Phase 1: Configure the Linux web tier"
  hosts: webservers
  roles: [webserver]

- name: "Phase 2: Configure the Windows management host"
  hosts: mgmt1
  roles: [windows-mgmt]

- name: "Phase 3: Apply baseline hardening to all branch office hosts"
  hosts: branch_office
  roles: [hardening]
```

That's it. Three plays, three roles, three target groups. Every component you've built today, composed into 25 lines of YAML.

**The convention:** `site.yml` at the top of the repo is the canonical "build the whole thing" entry point. When you join a new team and they hand you their Ansible repo, the first thing you look for is `site.yml` — that's the file that tells you how everything fits together.

## Step 2 — Break something to prove the rebuild

Let's prove `site.yml` actually rebuilds from a partial state. Hop to web1 and uninstall nginx:

```bash
ssh web1
sudo apt-get remove --purge -y nginx nginx-common
sudo rm -rf /var/www/branch-office /etc/nginx
exit
```

You're back on control. Confirm the breakage:

```bash
curl http://web1
```

Should fail with `Connection refused` (no nginx listening on port 80).

## Step 3 — Run site.yml

```bash
ansible-playbook playbooks/site.yml
```

This will take 5-10 minutes the first time because:
- Phase 1: rebuilds nginx + the templated page on web1 (lots of `changed`), confirms web2 (lots of `ok`)
- Phase 2: confirms mgmt1's Chocolatey installs (mostly `ok`), runs the inventory report
- Phase 3: confirms the hardening baseline on all three hosts (mostly `ok`)

**Watch the output.** You'll see Ansible work its way through the three phases. The PLAY headers tell you which phase you're in. Each role's task names are prefixed with the role name (e.g., `webserver : Install nginx`).

By the end, you should see something like:

```
PLAY RECAP *********************************************************************
mgmt1                      : ok=25   changed=0    unreachable=0    failed=0
web1                       : ok=23   changed=8    unreachable=0    failed=0
web2                       : ok=23   changed=0    unreachable=0    failed=0
```

web1 had `changed=8` because we tore down nginx and the playbook rebuilt it. web2 and mgmt1 had `changed=0` because they were already in the desired state.

## Step 4 — Verify the end state

```bash
# web1 should serve the templated page
curl http://web1

# web2 should serve the same templated page
curl http://web2

# mgmt1 should respond to win_ping
ansible mgmt1 -m ansible.windows.win_ping
```

Or if you still have the SSH port forwards open, refresh `http://localhost:8080` (web1) and `http://localhost:8081` (web2) in your browser. Both should show the branch office status page.

The `site.yml` rebuild is complete. **You just rebuilt your entire branch office from scratch with one command.** That command would work just as well against twenty branch offices, or two hundred — same playbook, just point it at a bigger inventory.

## Step 5 — Drift correction

Real environments drift. Someone SSHs into a server, edits a config file by hand, forgets about it. Six months later, that server behaves differently from the others and nobody knows why.

Idempotent automation prevents this. **You can run `site.yml` on a schedule** (every hour, every day, after every deploy) and it will continuously correct any drift it finds.

Try it:

```bash
ssh web1
sudo sed -i 's|root /var/www/branch-office;|root /var/www/wrong-path;|' /etc/nginx/sites-enabled/branch-office
sudo systemctl reload nginx
curl http://localhost
exit
```

`curl http://localhost` from web1 will now return a 404 because nginx is looking in `/var/www/wrong-path/` (which doesn't exist). The host is in a broken state.

Now run `site.yml` again:

```bash
cd ~/workshop
ansible-playbook playbooks/site.yml
```

Watch web1's "Deploy the nginx site config from template" task — it'll report `changed`. The handler "Reload nginx" will fire. Verify:

```bash
curl http://web1
```

The branch office page is back. **Ansible noticed the file's content didn't match what the template would produce, regenerated it, and reloaded nginx.** That's drift correction. Set up a cron job that runs `site.yml` every hour, and your fleet stays in compliance with the desired state automatically.

## Step 6 — Discussion: where do you go from here?

A few directions you might explore on your own time:

**Add a new role.** Try writing a `monitoring` role that installs and configures Prometheus node_exporter on the Linux hosts. Add it to `site.yml` Phase 4. The pattern is the same one you used for `webserver` — directory structure, role variables, tasks, handlers.

**Switch to dynamic inventory.** Instead of the static `inventory/hosts.yml`, point Ansible at Azure / AWS / vSphere / your hypervisor of choice and have it discover hosts automatically. The `azure.azcollection` you've been using has a dynamic inventory plugin called `azure_rm`. Same playbooks, dynamic targets.

**Set up a control plane.** Tools like AWX (open source) and Ansible Automation Platform (commercial) wrap your Ansible repo in a web UI with scheduling, RBAC, audit logging, and a visual playbook runner. If you're going to run Ansible in production, you'll want one of these.

**Integrate with CI/CD.** Trigger `site.yml` from GitHub Actions / GitLab CI / Azure DevOps every time someone merges to main. Combine with `--check --diff` in pull requests for automatic drift reports.

**Write tests.** The Ansible community uses Molecule for role testing — spin up a temporary VM, run your role, assert state, tear down. Production-grade roles have Molecule tests for every supported platform.

**Look at the rest of the ecosystem.** Ansible Vault is a stepping stone — production teams use HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault as the source of truth and pull secrets into Ansible at runtime via lookups. The `community.hashi_vault` collection is a good starting point.

## End of section 4.3

You should now have:

- A working `playbooks/site.yml` that orchestrates every role you've built today
- Personal experience tearing down a host and watching site.yml rebuild it
- Personal experience watching site.yml correct manual config drift
- A mental map of where Ansible fits in the broader IaC ecosystem (control plane, dynamic inventory, secrets stores, testing)

You're done with the hands-on portion of the workshop. Section 4.4 (wrap-up) is presenter-led — sit back, ask questions, take a breath.

## Stretch goals

- Add a `--tags` annotation to one of the role's tasks (e.g., `tags: nginx`) and try running `ansible-playbook playbooks/site.yml --tags nginx`. Ansible will run only tasks marked with that tag. Useful for "I just want to push a config change, skip all the other stuff."
- Read about the `--limit` flag combined with `site.yml`: `ansible-playbook playbooks/site.yml --limit web1` runs the entire site playbook but only against web1. Combine with `--check --diff` to see what would change.
- Browse https://github.com/ansible-community for community-maintained roles and collections in production use today.

## Checkpoint

Complete state in `checkpoints/section-4.3/`. This is the same content as the workshop's main `~/workshop/` repo at the end of the day — they're identical at this point.
