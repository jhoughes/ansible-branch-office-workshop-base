# Section 3.3 — Orchestration & Rolling Deploys

> **Duration:** 15 minutes
> **Presenter:** Joe (from stage) + Mike (on the floor)
> **Your goal:** Add a second web server (`web2`) to your inventory's web tier, then run a rolling deployment that updates both web servers one at a time — never both at once — using Ansible's orchestration features.

## Why this section exists

Up to now, every playbook you've run has hit one host at a time (web1, then mgmt1, etc.) and even when a play targeted a group, Ansible processed all hosts in that group in parallel. That's fine for setup, where parallelism is exactly what you want. It's not fine for **deploys**.

When you're deploying a new application version to a fleet of web servers, you almost never want all of them to go down at once. The standard pattern is:

1. Take host #1 out of the load balancer
2. Apply changes to host #1
3. Verify host #1 is healthy
4. Put host #1 back in the load balancer
5. Move to host #2 — repeat
6. Continue until all hosts are done

This pattern is called a **rolling deployment**. It keeps the service available throughout the deploy, and it stops the deploy automatically if any single host fails — limiting blast radius.

Ansible has built-in support for this via the `serial:` keyword and `pre_tasks` / `post_tasks` hooks. This section walks you through using them.

## What you'll do in this section

1. Verify that `web2` exists and is reachable (it was provisioned alongside web1, but the workshop hasn't touched it until now)
2. Apply the `webserver` role to web2 so both web servers are running the same configuration
3. Look at the rolling deploy playbook (`06-rolling-deploy.yml`) and understand its structure
4. Make a content change (edit the branch ID) and run the rolling deploy
5. Watch web1 finish ALL its tasks before web2 starts ANY of its tasks — that's `serial: 1`
6. Use `--limit` to deploy to just one host as a final exercise

## Step 1 — Verify web2 exists

`web2` was provisioned by your instructor's lab build alongside web1 — it's been sitting there idle the whole workshop, waiting for this section. Confirm it's reachable:

```bash
cd ~/workshop
ansible web2 -m ping
```

You should see:

```
web2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

If you get an `unreachable` error, raise your hand — your lab may need attention.

> **Why was web2 already there?** Real-world standard is that adding a new server to a load balancer pool is a coordination step, not the moment you actually start setting up the server. The lab follows the same pattern: web2 has been provisioned and waiting; section 3.3 is when we *bring it into the configuration*. In a real deploy, you might have ten new web servers all sitting around stamped from a golden image, waiting for someone to write the Ansible inventory entry that adopts them.

## Step 2 — Apply the webserver role to web2

The `webservers` group in `inventory/hosts.yml` already includes both web1 and web2. The webserver role hasn't run against web2 yet, but we can fix that with one command:

```bash
ansible-playbook playbooks/03-web-tier-with-roles.yml --limit web2
```

The `--limit` flag restricts a play to a subset of its target hosts. Even though the playbook says `hosts: web1`, this run only touches web2... wait, no it doesn't. The `--limit` flag can only NARROW the host list, not expand it. The playbook says `hosts: web1`, so `--limit web2` would result in zero hosts.

**Let's fix the playbook.** Edit `playbooks/03-web-tier-with-roles.yml` and change the host list to `webservers`:

```bash
nano playbooks/03-web-tier-with-roles.yml
```

Change the `hosts:` line from `web1` to `webservers`:

```yaml
- name: Configure the branch office web tier (using the webserver role)
  hosts: webservers           # was: web1
  become: true

  roles:
    - webserver
```

Save and exit. Now run it limited to web2:

```bash
ansible-playbook playbooks/03-web-tier-with-roles.yml --limit web2
```

You'll see web2 get nginx installed, the templated status page deployed, the firewall opened — exactly the same first-run output you saw for web1 in section 2.1. After ~30 seconds, web2 has the same configuration as web1.

Confirm by setting up a new SSH port forward to web2:

```bash
# In a fresh terminal on your laptop
ssh -L 8081:10.NN.0.11:80 attendee@<your-control-ip>
```

(Replace `NN` with your attendee number.) Then open `http://localhost:8081` — you should see the same branch office status page, but with web2's hostname and IP showing in the server info section. **Two web servers, one role, identical configuration.**

## Step 3 — Look at the rolling deploy playbook

```bash
cat playbooks/06-rolling-deploy.yml
```

The key elements:

```yaml
- name: Rolling deploy of web tier — one host at a time
  hosts: webservers              # both web1 and web2
  become: true
  serial: 1                      # ← THE MAGIC: one host at a time
  max_fail_percentage: 0         # ← stop the deploy if ANY host fails
```

Then `pre_tasks:` (drain from LB — simulated), then `roles: [webserver]` (apply the role), then `post_tasks:` (health check + return to LB). Each host runs through ALL of these phases sequentially before the next host starts.

**The simulated LB integration:**

```yaml
pre_tasks:
  - name: "Drain {{ inventory_hostname }} from the load balancer (simulated)"
    ansible.builtin.debug:
      msg: |
        → would call LB API now to remove {{ inventory_hostname }} from rotation.
        → would wait for in-flight connections to drain (typically 30-60s).
```

In a real environment, the debug message would be replaced by an actual API call to your load balancer — `community.aws.elb_target` for AWS, `community.general.haproxy` for HAProxy, F5 modules for BIG-IP, etc. The lab has no LB, so we narrate what would happen. **The pattern doesn't care which LB you have** — pre_tasks/post_tasks is the integration point.

The post_tasks include a real health check via the `uri` module:

```yaml
post_tasks:
  - name: "Confirm nginx on {{ inventory_hostname }} is responding"
    ansible.builtin.uri:
      url: "http://localhost/health"
      return_content: true
      status_code: 200
    retries: 5
    delay: 2
    until: health_check.status == 200
```

This hits the `/health` endpoint on each web server (configured by the webserver role's nginx site config) and only proceeds if it returns 200. If it doesn't, the play fails. Combined with `max_fail_percentage: 0`, this means **a single broken host stops the entire deploy** — the remaining hosts stay on the old version until you've fixed the issue. Production-safe by default.

## Step 4 — Make a content change and roll it out

Edit the branch metadata to simulate a real-world content update:

```bash
nano inventory/group_vars/all.yml
```

Change the `branch_id` and `branch_location`:

```yaml
branch_id: "BR-RAINIER"
branch_location: "Mount Rainier Operations Center"
```

Save and exit. Now run the rolling deploy:

```bash
ansible-playbook playbooks/06-rolling-deploy.yml
```

**Watch the output carefully.** You'll see something like:

```
PLAY [Rolling deploy of web tier — one host at a time] *************************

TASK [Gathering Facts] *********************************************************
ok: [web1]                          ← web1 only

TASK [Drain web1 from the load balancer (simulated)] **************************
ok: [web1] => {
  "msg": "→ would call LB API now to remove web1 from rotation..."
}

TASK [Confirm web1 is out of rotation (simulated)] ****************************
ok: [web1] => {...}

TASK [webserver : Install nginx] ***********************************************
ok: [web1]
TASK [webserver : Create the document root directory] **************************
ok: [web1]
TASK [webserver : Deploy the branch office status page from template] *********
changed: [web1]              ← the template change
... (more webserver role tasks, web1 only) ...

TASK [Confirm nginx on web1 is responding] ************************************
ok: [web1]

TASK [Return web1 to the load balancer (simulated)] ***************************
ok: [web1]

PLAY [Rolling deploy of web tier — one host at a time] *************************

TASK [Gathering Facts] *********************************************************
ok: [web2]                          ← NOW web2, not before

TASK [Drain web2 from the load balancer (simulated)] **************************
... (web2 goes through the entire same cycle) ...

PLAY RECAP *********************************************************************
web1                       : ok=14   changed=1    unreachable=0    failed=0
web2                       : ok=14   changed=1    unreachable=0    failed=0
```

**The important thing:** notice that web1 finishes EVERY task — drain, role, health check, return — before web2 starts ANY task. That's `serial: 1`.

Refresh `http://localhost:8080` (web1) and `http://localhost:8081` (web2) in your browser. Both pages show the new "BR-RAINIER" / "Mount Rainier" content.

In a real deploy, the time between "web1 returns to rotation healthy" and "web2 starts draining" would be measured in seconds, but during that window you'd have one server with the new version and one with the old version actively serving traffic. That's totally fine for content changes; it's a problem if your deploy includes a database migration that breaks old code. Real-world deploy strategies have an entire genre of patterns for handling that (blue-green, canary, expand/contract migrations, etc.) — but they all rest on this `serial:` foundation.

## Step 5 — Use `--limit` for targeted deploys

Sometimes you want to deploy to just one host — for testing, or for fixing a single problem child. The `--limit` flag does that:

```bash
ansible-playbook playbooks/06-rolling-deploy.yml --limit web2
```

This runs the rolling deploy playbook against only web2, skipping web1 entirely. Useful when you've made a change you want to validate against a single host before rolling it everywhere.

You can also limit to multiple hosts:

```bash
ansible-playbook playbooks/06-rolling-deploy.yml --limit "web1:web2"
ansible-playbook playbooks/06-rolling-deploy.yml --limit "webservers:!web1"
```

The second one says "all hosts in webservers EXCEPT web1." Useful when you're deliberately holding back a canary.

## End of section 3.3

You should now have:

- web2 fully provisioned and configured (same `webserver` role as web1)
- `playbooks/03-web-tier-with-roles.yml` updated to target the `webservers` group instead of just `web1`
- A working rolling deploy playbook at `playbooks/06-rolling-deploy.yml`
- A new branch identity (`BR-RAINIER`) deployed to both web servers via the rolling deploy
- Personal experience with `serial:`, `pre_tasks`, `post_tasks`, `--limit`, and `max_fail_percentage`

You're ready for section 3.4, the multi-platform full stack run checkpoint, then the break.

## Stretch goals

- Try `serial: 2` instead of `serial: 1`. With only two web servers, this defeats the whole point — but it shows you the syntax for "deploy 2 at a time" when you have 10 web servers.
- Try `serial: "50%"` — Ansible accepts percentages too. Useful for "deploy to half the fleet, validate, deploy to the other half."
- Add a real failure to one host's playbook target temporarily (e.g., set `webserver_listen_port: notanumber` for web2 only) and run the rolling deploy. Watch how `max_fail_percentage: 0` stops the run before web2 finishes, leaving web1 successfully updated.

## Checkpoint

Complete state in `checkpoints/section-3.3/`. To use it:

```bash
cd ~/workshop/checkpoints/section-3.3
ansible-playbook playbooks/06-rolling-deploy.yml
```
