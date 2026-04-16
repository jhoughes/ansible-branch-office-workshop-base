# Section 2.1 — Writing Your First Real Playbook

> **Duration:** 15 minutes
> **Presenter:** Joe (from stage) + Mike (on the floor)
> **Your goal:** Install nginx on web1, deploy a Jinja2-templated status page, and see it in your browser through the SSH tunnel from section 1.4.

## What you'll do in this section

1. Run a trivial "hello world" playbook to see Ansible's output structure
2. Run the web tier playbook to install nginx and deploy a templated status page
3. Refresh `http://localhost:8080` in your browser and see the branch office status page
4. Change a variable, re-run the playbook, watch the page update — the Jinja2 magic moment

---

## Step 1 — Run the "hello world" playbook

Your control node terminal (terminal 1 from section 1.4) should still be at `~/workshop`. If not:

```bash
cd ~/workshop
```

Run the hello world playbook:

```bash
ansible-playbook playbooks/01-hello-world.yml
```

This installs `chrony` (a time sync service) on web1 and ensures it's running. It's deliberately trivial — the point is to look at the output structure before you run anything more complicated.

**Expected output** (abbreviated):

```
PLAY [Hello world — ensure chrony is installed and running on web1] ************

TASK [Gathering Facts] *********************************************************
ok: [web1]

TASK [Install chrony] **********************************************************
ok: [web1]

TASK [Ensure chrony service is started and enabled at boot] ********************
ok: [web1]

TASK [Check chrony's current sync status] **************************************
ok: [web1]

TASK [Show chrony status] ******************************************************
ok: [web1] =>
  msg:
  - 'Reference ID    : ...'
  - 'Stratum         : 3'
  - 'Ref time (UTC)  : ...'
  - ...

PLAY RECAP *********************************************************************
web1                       : ok=5    changed=0    unreachable=0    failed=0
```

**Notice three things:**

1. **Every task says `ok`, not `changed`.** Chrony is already installed and running on Ubuntu by default, so Ansible looked at the desired state, compared it to the actual state, and decided no changes were needed. **This is idempotency.** You can run this playbook 100 times in a row and the second run onwards will look identical to the first.

2. **The `Gathering Facts` task happens automatically.** Ansible connected to web1 and asked the host "tell me about yourself" — kernel version, IP, distro, memory, CPU count, etc. Those facts are now available in the playbook for templates and conditionals. You'll use them in the next step.

3. **The PLAY RECAP at the bottom** summarizes the run. `ok=5`, `changed=0`, no failures. That's a successful playbook run that made no actual changes. Idempotency in action.

> **Try it:** run the playbook again with `ansible-playbook playbooks/01-hello-world.yml`. Same output. Same recap. Nothing changes because nothing needs to.

---

## Step 2 — Look at the web tier playbook before running it

Before you run the next playbook, take a moment to read it:

```bash
cat playbooks/02-web-tier.yml
```

(Or open it in your editor with `nano playbooks/02-web-tier.yml` — same idea.)

**Things to notice:**

- The play targets `hosts: web1` and uses `become: true` because installing packages and writing files in `/etc/nginx` requires root.
- The `vars:` block defines three variables (`nginx_listen_port`, `nginx_document_root`, `nginx_site_name`) that are used throughout the rest of the play. Defining them at the top makes the playbook easy to customize.
- There's a `template` task that copies `templates/status.html.j2` to web1 and renders it with variables and facts.
- There's a `handlers:` section at the bottom with one handler (`Reload nginx`). Several tasks use `notify: Reload nginx` — this means "if you actually changed anything, fire the handler at the end of the play." Handlers only run if at least one notifying task reported a change. They run *once*, no matter how many times they were notified.

This pattern (task changes config → notify handler → handler reloads service at end of play) is the canonical Ansible pattern for safely managing services.

---

## Step 3 — Run the web tier playbook

```bash
ansible-playbook playbooks/02-web-tier.yml
```

This will take 30-90 seconds the first time because it has to download and install nginx. Subsequent runs will be much faster.

**Expected output** (abbreviated, first run):

```
PLAY [Configure the branch office web tier] ************************************

TASK [Gathering Facts] *********************************************************
ok: [web1]

TASK [Install nginx] ***********************************************************
changed: [web1]

TASK [Create the document root directory] **************************************
changed: [web1]

TASK [Deploy the branch office status page from template] **********************
changed: [web1]

TASK [Deploy the nginx site config from template] ******************************
changed: [web1]

TASK [Enable the branch office site] *******************************************
changed: [web1]

TASK [Remove the default nginx site] *******************************************
changed: [web1]

TASK [Allow HTTP through ufw] **************************************************
changed: [web1]

TASK [Ensure nginx is started and enabled] *************************************
ok: [web1]

RUNNING HANDLER [Reload nginx] *************************************************
changed: [web1]

PLAY RECAP *********************************************************************
web1                       : ok=10   changed=8    unreachable=0    failed=0
```

**Notice:**

- Almost every task says `changed`. That's expected on the first run — nothing existed before, everything is new.
- The `Reload nginx` handler ran **after** all the regular tasks, and only because three tasks notified it. Even though three tasks notified, the handler ran once.
- `nginx is started and enabled` says `ok` because the install task already started nginx as part of its package post-install — by the time we got here, nothing needed to change.

---

## Step 4 — See the status page in your browser

You should still have terminal 2 from section 1.4 running the SSH port forward to web1's port 80. Refresh `http://localhost:8080` in your browser.

**You should now see the branch office status page** — a styled HTML page showing:

- The branch ID, location, and environment
- The server hostname, OS, kernel, IP, CPU count, memory
- A "Healthy" status indicator
- A timestamp showing when the page was generated by Ansible
- A footer explaining what just happened

**This is the magic moment.** Every value on that page came from one of two sources:

- **Workshop variables** (like `branch_id` and `branch_location`) defined in `inventory/group_vars/all.yml` and rendered into the template by Ansible
- **Ansible facts** (like `ansible_hostname`, `ansible_kernel`, `ansible_default_ipv4.address`) gathered automatically when the playbook ran

The HTML file on web1 didn't exist before you ran this playbook. Ansible took the `status.html.j2` template, substituted in the variables and facts, wrote the result to `/var/www/branch-office/index.html`, and configured nginx to serve it. Then the handler reloaded nginx so the new config took effect. All in about 30 seconds, with one command.

> **If you don't see the page:** check that terminal 2 is still running the SSH port forward. If it died (closed terminal, network blip, sleeping laptop), re-run the `ssh -L 8080:10.NN.0.10:80 attendee@<control-ip>` command from section 1.4 step 5.

### Troubleshooting step 4

| Symptom | Fix |
|---|---|
| Browser shows "Welcome to nginx!" default page | The default site wasn't removed — re-run the playbook |
| Browser shows old/cached version | Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (macOS) |
| Browser shows `ERR_CONNECTION_REFUSED` | Port forward died — re-run the `ssh -L` from section 1.4 step 5 |
| Browser shows 404 | Either nginx isn't running or the site config wasn't enabled — re-run the playbook |

---

## Step 5 — Change a variable and re-run (the Jinja2 magic moment)

This is the moment that makes templates click. Edit the workshop's group_vars file:

```bash
nano inventory/group_vars/all.yml
```

Find these two lines:

```yaml
branch_id: "BR-001"
branch_location: "Seattle"
```

Change them to whatever you want. Examples:

```yaml
branch_id: "BR-247"
branch_location: "Reykjavik"
```

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X` for nano).

Re-run the web tier playbook:

```bash
ansible-playbook playbooks/02-web-tier.yml
```

**Expected output** (abbreviated, second run with variable change):

```
PLAY [Configure the branch office web tier] ************************************

TASK [Gathering Facts] *********************************************************
ok: [web1]

TASK [Install nginx] ***********************************************************
ok: [web1]

TASK [Create the document root directory] **************************************
ok: [web1]

TASK [Deploy the branch office status page from template] **********************
changed: [web1]                                  ← only this task reported changed!

TASK [Deploy the nginx site config from template] ******************************
ok: [web1]

TASK [Enable the branch office site] *******************************************
ok: [web1]

TASK [Remove the default nginx site] *******************************************
ok: [web1]

TASK [Allow HTTP through ufw] **************************************************
ok: [web1]

TASK [Ensure nginx is started and enabled] *************************************
ok: [web1]

PLAY RECAP *********************************************************************
web1                       : ok=9    changed=1    unreachable=0    failed=0
```

**Notice:**

- Out of 9 tasks, **only one reported `changed`**: the template task. That's because only the template's output is different (it now has the new values you set).
- The other tasks all said `ok` because nothing about them changed: nginx is already installed, the site is already enabled, the firewall rule is already in place.
- **The handler did NOT run** this time, because only the document root content changed (not the nginx config). nginx serves the new HTML on the next request without needing a reload.
- **This is the value of declarative configuration management.** You didn't have to think about "do I need to reinstall nginx?" or "do I need to reload?". Ansible figured all of that out.

Now refresh `http://localhost:8080` in your browser. **The page now shows the new branch ID and location.**

You changed two values in a YAML file, ran one command, and Ansible updated exactly the right thing on the target host. That's the workflow you came here to learn.

---

## End of section 2.1

You should now have:

- nginx installed and running on web1
- A Jinja2-templated branch office status page being served at port 80
- A working SSH port forward exposing it at `http://localhost:8080` on your laptop
- Personal experience with editing variables and seeing the changes take effect

You're ready for section 2.2, where you'll refactor this same playbook into a proper role structure.

## Stretch goals (if you finished early)

- Add a new variable to `inventory/group_vars/all.yml` (e.g., `support_email: "it@example.com"`) and add it to the status page template (`templates/status.html.j2`). Re-run the playbook and see your new field appear.
- Look at the Ansible facts available for web1 by running:
  ```bash
  ansible web1 -m setup | less
  ```
  There are dozens of facts you could add to the status page. Pick one and add it.
- Read `LAB-2.2.md` so you're ready for the role refactor section.

## Checkpoint

If your repo got into a confused state, the complete expected state of the repo at the end of this section is in `checkpoints/section-2.1/`. To use it:

```bash
cd ~/workshop/checkpoints/section-2.1
ansible-playbook playbooks/02-web-tier.yml
```

That will run the section 2.1 playbook against your lab from a known-good copy. You can then either continue from inside the checkpoint directory or copy the relevant files back to `~/workshop` to continue from there.

See `docs/captures/section-2.1-web-tier.txt` for what a successful run looks like end-to-end.
