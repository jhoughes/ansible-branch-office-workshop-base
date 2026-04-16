# Section 2.2 — Refactor Into Roles

> **Duration:** 15 minutes
> **Presenter:** Mike (from stage) + Joe (on the floor)
> **Your goal:** Take the monolithic playbook from section 2.1 and refactor it into a proper role. See why roles matter by comparing the before and after side by side.

## Why this section exists

The playbook you wrote in section 2.1 (`playbooks/02-web-tier.yml`) is fine — it works, it's idempotent, it solves the problem. But it has one structural weakness: **everything is inline**. The variables, the tasks, the templates, the handlers — all in one file.

That's fine when you have one playbook for one job. It stops being fine when:

- You want to apply the same web tier setup to a second host (web2) in a different playbook
- You want to share your web tier setup with another team
- You want to publish your web tier setup to Ansible Galaxy
- You have ten roles, each with their own variables, and they start colliding

The Ansible answer is **roles**. A role is a directory with a specific structure that contains everything one logical "unit of configuration" needs: tasks, variables, templates, files, handlers, and metadata. You apply a role to a host, and Ansible knows where to find everything because the structure is conventional.

In this section, you'll refactor `02-web-tier.yml` into a `webserver` role. The behavior won't change — but the structure will, dramatically.

---

## What you'll do in this section

1. Look at the existing `webserver` role in the repo
2. Compare the role to the section 2.1 monolithic playbook
3. Run the new role-based playbook (`03-web-tier-with-roles.yml`) and confirm the behavior is identical
4. Override a role default from the playbook to see how customization works
5. Understand why this matters

---

## Step 1 — Look at the role's structure

The role already exists in the repo at `roles/webserver/`. Look at its directory tree:

```bash
cd ~/workshop
tree roles/webserver/
```

You should see:

```
roles/webserver/
├── defaults/
│   └── main.yml          ← default variable values (was the play's vars: block)
├── files/                ← static files to copy (empty for this role)
├── handlers/
│   └── main.yml          ← handlers (was the play's handlers: section)
├── meta/
│   └── main.yml          ← role metadata (author, license, dependencies)
├── tasks/
│   └── main.yml          ← the actual tasks (was the play's tasks: list)
└── templates/
    ├── nginx-site.conf.j2  ← templates (no path prefix needed in role tasks!)
    └── status.html.j2
```

This directory layout is the standard Ansible role layout. Every role you'll ever see — your own, your team's, ones from Galaxy — follows this same structure. Once you know it, you can navigate any role in seconds.

**Open each file briefly and look at it:**

```bash
cat roles/webserver/defaults/main.yml
cat roles/webserver/handlers/main.yml
cat roles/webserver/tasks/main.yml
cat roles/webserver/meta/main.yml
```

Notice in `tasks/main.yml`:
- The template paths are just filenames (`status.html.j2`), not paths (`../templates/status.html.j2`). When called from a role, the `template` module automatically looks in the role's own `templates/` directory.
- The variables are prefixed with `webserver_` (e.g., `webserver_listen_port` instead of `nginx_listen_port`). This is a **strong convention** — every role should prefix its variables with the role name to avoid collisions when you use multiple roles together.

---

## Step 2 — Compare to the section 2.1 playbook

Open the two playbooks side by side. The section 2.1 version:

```bash
cat playbooks/02-web-tier.yml
```

The new section 2.2 version:

```bash
cat playbooks/03-web-tier-with-roles.yml
```

The new playbook is approximately **10 lines**. The old one is **~80 lines**. They do exactly the same thing.

```yaml
# playbooks/03-web-tier-with-roles.yml
- name: Configure the branch office web tier (using the webserver role)
  hosts: web1
  become: true

  roles:
    - webserver
```

That's it. The playbook says "for host web1, apply the webserver role." Ansible looks in `roles/webserver/`, finds the conventional structure, and runs everything in the right order. Tasks run in the order defined in `tasks/main.yml`. Handlers in `handlers/main.yml` are registered and fire if notified. Default variables in `defaults/main.yml` are loaded automatically.

**The behavior is identical to the section 2.1 playbook.** The only thing that changed is *how the code is organized*.

---

## Step 3 — Run the role-based playbook

```bash
ansible-playbook playbooks/03-web-tier-with-roles.yml
```

**Expected output** (if web1 is in the post-section-2.1 state, everything will be `ok`):

```
PLAY [Configure the branch office web tier (using the webserver role)] *********

TASK [Gathering Facts] *********************************************************
ok: [web1]

TASK [webserver : Install nginx] ***********************************************
ok: [web1]

TASK [webserver : Create the document root directory] **************************
ok: [web1]

TASK [webserver : Deploy the branch office status page from template] **********
ok: [web1]

TASK [webserver : Deploy the nginx site config from template] ******************
ok: [web1]

TASK [webserver : Enable the branch office site] *******************************
ok: [web1]

TASK [webserver : Remove the default nginx site] *******************************
ok: [web1]

TASK [webserver : Allow HTTP through ufw] **************************************
ok: [web1]

TASK [webserver : Ensure nginx is started and enabled] *************************
ok: [web1]

PLAY RECAP *********************************************************************
web1                       : ok=9    changed=0    unreachable=0    failed=0
```

**Notice the task names.** Each one is now prefixed with `webserver : ` — that's Ansible telling you "this task came from the webserver role." When you have a playbook applying five roles, this prefix makes it instantly clear which role is doing what.

Refresh your browser at `http://localhost:8080`. The page should look identical to what you saw at the end of section 2.1, because the role does the same thing as the section 2.1 playbook.

---

## Step 4 — Override a role default at the call site

Roles are reusable because you can override their defaults without changing the role itself. Try it.

Edit `playbooks/03-web-tier-with-roles.yml` and add a vars block:

```yaml
---
- name: Configure the branch office web tier (using the webserver role)
  hosts: web1
  become: true

  vars:
    webserver_site_name: branch-office-customized

  roles:
    - webserver
```

Save and run:

```bash
ansible-playbook playbooks/03-web-tier-with-roles.yml
```

**Expected output** (relevant tasks change because the site name changed):

```
TASK [webserver : Deploy the nginx site config from template] ******************
changed: [web1]

TASK [webserver : Enable the branch office site] *******************************
changed: [web1]

TASK [webserver : Remove the default nginx site] *******************************
ok: [web1]

...

RUNNING HANDLER [webserver : Reload nginx] *************************************
changed: [web1]

PLAY RECAP *********************************************************************
web1                       : ok=10   changed=3    unreachable=0    failed=0
```

You changed one variable value at the call site. The role used the new value everywhere it referenced `webserver_site_name`. The role itself did not have to be modified. **That's the value of roles.** Different playbooks can use the same role with different settings without forking the code.

> **Reset before continuing:** remove the `vars:` block you added (or change `webserver_site_name` back to `branch-office`) and run the playbook one more time. We want the lab in a clean state for section 2.3.

---

## Step 5 — Why this matters in 30 seconds

In real environments, you'll write dozens of roles. Each one gets:

- Its own directory with a known structure
- Its own variables, namespaced to avoid collisions
- Its own templates and files, found automatically
- Its own metadata (author, license, dependencies, supported platforms)

You compose those roles together in playbooks. A playbook for a database server might apply roles `[base, hardening, postgres, monitoring]`. A playbook for a web server might apply `[base, hardening, webserver, monitoring]`. The `base`, `hardening`, and `monitoring` roles are shared — written once, used everywhere.

This is how production Ansible codebases stay maintainable. Sections 3.1 (hardening) and 2.3 (Windows) will both build their logic as roles, so by the end of the workshop you'll have a small library of reusable roles you can mix and match.

---

## End of section 2.2

You should now have:

- A `webserver` role at `roles/webserver/` with the standard layout
- A 10-line playbook (`playbooks/03-web-tier-with-roles.yml`) that uses the role
- An understanding of how role variables, templates, and handlers work
- The branch office status page still serving correctly at `http://localhost:8080` (cleaned up after step 4)

You're ready for section 2.3, where Mike leads you through the Windows half of the lab using the same patterns — but with PowerShell modules and the `mgmt1` host instead of nginx and `web1`.

## Stretch goals (if you finished early)

- Look at a real-world role from Ansible Galaxy: `geerlingguy.nginx` is a great example. Browse it at https://github.com/geerlingguy/ansible-role-nginx and notice the same directory structure with much more sophisticated tasks.
- Try `ansible-galaxy role init my_test_role` in `~/workshop/roles/` to see Ansible scaffold a brand-new empty role with the full directory structure.
- Read the `meta/main.yml` file in the `webserver` role and the `geerlingguy.nginx` role. Notice how published Galaxy roles use the metadata to declare supported platforms.

## Checkpoint

The complete state of the repo at the end of this section is in `checkpoints/section-2.2/`. To use it:

```bash
cd ~/workshop/checkpoints/section-2.2
ansible-playbook playbooks/03-web-tier-with-roles.yml
```

See `docs/captures/section-2.2-roles-refactor.txt` for what a successful run looks like.
