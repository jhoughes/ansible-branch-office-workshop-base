# Section 4.1 — Testing & Debugging

> **Duration:** 15 minutes
> **Presenter:** Mike (from stage) + Joe (on the floor)
> **Your goal:** Run a deliberately broken playbook and use Ansible's built-in debugging flags to find and fix the bugs. Build the diagnostic muscle you'll use every day in real Ansible work.

## Why this section exists

Every playbook you've run today has worked on the first try. That is not what real Ansible work looks like. In real Ansible work, you write a playbook, run it, watch it explode, fix something, run it again, watch it explode differently, fix the new thing, and so on. The skill that separates productive Ansible users from frustrated ones is **diagnosing failed runs quickly**.

Ansible has a small set of built-in flags that, used together, will resolve >90% of playbook failures. This section walks you through them by giving you a deliberately broken playbook with five different bugs and asking you to find them.

## What you'll do in this section

1. Look at the broken playbook (without studying it for too long — the point is to diagnose it dynamically)
2. Run it in **check mode** with `--check --diff` to see what it WOULD do
3. Watch the run fail; use `-vvv` to get the full error
4. Use `--start-at-task` to skip past tasks that already succeeded
5. Use `--step` to walk the playbook one task at a time
6. Compare your findings to the answer key at the bottom

---

## Step 1 — Look at the broken playbook (briefly)

```bash
cd ~/workshop
cat playbooks/broken/broken-web-deploy.yml
```

Don't try to find all the bugs by reading. **The whole point of this section is to use Ansible's tools to find them**, not to spot them by eye. Read the playbook for a minute to get the overall flow:

- Backs up the current index.html
- Drops a deployment marker file
- Adds a cache header to the nginx site config
- Confirms nginx is healthy after the change
- Updates the branch metadata in group_vars

Move on to step 2 even if you think you've already spotted bugs.

---

## Step 2 — Run in check mode with diff

`--check` is the single most important flag you'll learn today. It runs the playbook in "what would happen" mode without making any changes. `--diff` is its essential companion — it shows you the actual content differences each task would apply.

```bash
ansible-playbook playbooks/broken/broken-web-deploy.yml --check --diff
```

Watch the output. You'll see some tasks succeed (in `--check` mode), some fail with errors, and for each task that touches a file, you'll see a unified diff of the changes it would make.

**This is your daily debugging tool.** Before running anything destructive in a real environment, run it in `--check --diff` first. You'll catch most bugs before they touch production.

---

## Step 3 — Run for real and use `-vvv` on the failure

Now run the playbook for real:

```bash
ansible-playbook playbooks/broken/broken-web-deploy.yml
```

Some tasks will succeed. The first one to fail will stop the playbook (Ansible's default behavior — fail fast). Read the error message carefully. **Most error messages tell you exactly what's wrong** if you read them slowly. People miss them because they panic when red text appears.

If the error message isn't enough, re-run with `-vvv` (three v's) for verbose output:

```bash
ansible-playbook playbooks/broken/broken-web-deploy.yml -vvv
```

**Verbosity levels:**

| Flag | What you get |
|---|---|
| (none) | Pretty output, summarized errors |
| `-v` | Adds command modules' return values |
| `-vv` | Adds module argument details and connection info |
| `-vvv` | Adds full SSH/WinRM debug — useful for connection and auth issues |
| `-vvvv` | Adds connection plugin internals — rarely needed |

For most bugs, `-vvv` is the right level. `-vvvv` is for "I think it's a connection problem and I need to see the wire."

---

## Step 4 — Use `--start-at-task` to skip past what already worked

Once you fix a bug and want to continue, you don't have to re-run the whole playbook from the top. Use `--start-at-task` to jump straight to where you got stuck:

```bash
ansible-playbook playbooks/broken/broken-web-deploy.yml \
  --start-at-task="Add cache-control header to nginx site config"
```

The argument is the task NAME (the string in the `name:` field). Ansible will skip every task before it, including the gathering facts task. **Use this when you're iterating on a fix and don't want to wait for everything before it to re-run.**

> **Caveat:** Tasks before the start point don't run, which means any variables they would have set, files they would have created, etc., will not exist. Most of the time this doesn't matter — but if your starting task depends on a `register:` from an earlier task, you'll get an "undefined variable" error. In that case, run from the top.

---

## Step 5 — Use `--step` to walk the playbook one task at a time

`--step` is interactive: Ansible asks "(N)o/(y)es/(c)ontinue" before EACH task. Useful when you want to:
- Watch each task's output before letting the next run
- Pause to inspect the host between tasks (open another terminal, look at /etc/nginx/, etc.)
- Bail out before a destructive task you're not sure about

Try it:

```bash
ansible-playbook playbooks/broken/broken-web-deploy.yml --step
```

Press `y` to run a task, `n` to skip it, `c` to continue without further prompts. **This is the slowest way to run a playbook — and exactly what you want when you're nervously iterating on something risky.**

---

## Step 6 — Fix the bugs

Work through the bugs one at a time. The order doesn't matter — Ansible fails on the first bug it hits, you fix that, run again, find the next bug, fix that, repeat.

Common diagnostic approaches:

| Symptom | What to try |
|---|---|
| Module fails with a clear message about a path or value | Look at the playbook line — is the path right? Look at the value — is it the type the module expects? |
| Module succeeds but does nothing | Add `register: result` and `debug: var=result` to see what the module returned |
| Module fails connecting | Run with `-vvv` and look at the SSH/WinRM lines |
| Variable is undefined | Search the playbook for where it should have been set; check if the task that sets it actually ran |
| Module runs but the next task fails because the change didn't happen | Is there an off-by-one in the file path? Is the service name spelled right? |

Once you've found and fixed all the bugs (or given up and looked at the answer key), the playbook should run cleanly:

```bash
ansible-playbook playbooks/broken/broken-web-deploy.yml
```

PLAY RECAP should show all `ok` and `changed` counts, no `failed`.

---

## Bonus diagnostic tools (mention only — you'll find them when you need them)

- **`ansible-playbook --syntax-check FILE`** — parses the YAML and validates module names without running anything. Catches typos in module names and basic YAML errors instantly.
- **`ansible-lint FILE`** — separate tool you'd install via pip. Catches a much broader range of style and correctness issues than syntax-check. Recommended for any team-shared playbook.
- **`ansible-playbook --list-tasks FILE`** — lists every task in the playbook without running anything. Useful for getting an overview of a playbook you didn't write.
- **`ansible-playbook --list-hosts FILE`** — lists which hosts the play would target. Useful when you have complex `hosts:` patterns and aren't sure who they resolve to.
- **The `debug` module with `var:`** — drop `- debug: var=some_variable_or_register` between tasks to inspect intermediate state. Cheap, easy, gets you out of most jams.

---

## End of section 4.1

You should now have:

- Practical experience running `--check --diff`, `-vvv`, `--start-at-task`, and `--step`
- A fixed version of `broken-web-deploy.yml` in your control node (the live one in your repo)
- A mental model for diagnosing playbook failures: read the error → reproduce with `--check` → narrow down with `-vvv` → iterate quickly with `--start-at-task` and `--step`

You're ready for section 4.2 (Joe's lecture on scaling/maintainability) and then the capstone in section 4.3.

## Stretch goals

- Pick any other playbook in the repo. Add an intentional bug (typo a path, misname a service, set a variable to the wrong type). Run it, diagnose with the techniques above, fix it. Build the muscle.
- Install `ansible-lint` (`pip install --break-system-packages ansible-lint`) and run it against the workshop's playbooks. Look at the issues it flags — many of them are improvements you'd want to make in real-world code.
- Read about Ansible's `assert` module — it lets you embed test assertions inside playbooks. Useful for catching state regressions.

---

## Answer key — five bugs in `broken-web-deploy.yml`

**Don't read this until you've tried diagnosing.**

<details>
<summary>Click to reveal</summary>

1. **Typo in nginx site config path** (task "Add cache-control header to nginx site config"): `/etc/nginx/sites-availble/branch-office` should be `/etc/nginx/sites-available/branch-office`. The `lineinfile` module fails because the file doesn't exist at the typo'd path.

2. **Typo in handler service name** (handler "Reload nginx"): `name: ngnix` should be `name: nginx`. Even if a notify-fired handler doesn't run during the failed run above, fixing #1 will trigger this one.

3. **Wrong port in health check** (task "Wait for nginx to come back up"): `url: "http://localhost:8080/health"` should be `http://localhost/health`. Port 8080 is the SSH-forwarded port on YOUR LAPTOP — on web1 itself, nginx listens on port 80.

4. **Missing fact gathering** (top of play): `gather_facts:` is not set, so it defaults to `true`, which is correct... BUT, the task "Drop the deployment marker file" uses `{{ ansible_date_time.iso8601 }}` which depends on facts having been gathered. (No actual bug here — included as a deliberate red herring. If you flagged this, good instinct, but in this specific playbook it's fine. Read the docs for `gather_facts` defaults.)

5. **Wrong file ownership for the line update** (task "Update the branch_id in the workshop metadata"): the playbook runs `become: true` (root) and modifies a file in `/home/attendee/workshop/inventory/group_vars/all.yml`. After the change, the file is owned by root, which breaks Ansible commands run later by the `attendee` user. Either the playbook should `chown` it back, or it should not `become: true` for this specific task. The "correct" fix is to add `become: false` to that one task.

(Bug #4 is a deliberate red herring — if you flagged it, congratulations, you read carefully. The playbook is intentionally only loosely broken so the diagnostic *workflow* is the lesson, not the count.)

</details>
