# How to Capture Lab Output

This document is for **workshop instructors** doing a lab build pass before workshop day. The goal is to run every section's playbooks against a real lab environment, capture the terminal output, and commit those captures so attendees have a reference for what success looks like.

## Why this matters

The lab guides (`LAB-X.Y.md`) reference output captures with statements like "your output should look like this." Without real captures, those statements are aspirational. With real captures, attendees can compare their results to a known-good run and immediately spot when something is off.

The capture pass is also the workshop's integration test. If a section breaks during the capture, fix it before workshop day. Don't ship a broken workshop and discover it in front of 25 attendees.

## What you need

- One fresh attendee lab environment in Azure (provisioned via the Pass 2 provisioning playbook)
- SSH access to the `control` node
- About 90 minutes of focused time to walk through every section
- The `capture.sh` script in this directory (runs from the workshop root on the control node)

## The capture protocol

### Step 1: Provision a clean lab

Don't capture against a lab that's already had test runs against it. State leaks in subtle ways. Provision a fresh attendee resource group.

```bash
cd provisioning/azure
ansible-playbook site.yml -e "attendee_count=1" -e "purpose=capture-pass"
```

Note the control node IP from the output.

### Step 2: SSH to the control node and clone the workshop

```bash
ssh attendee@<control-ip>
git clone https://github.com/jhoughes/ansible-branch-office-workshop-base.git workshop
cd workshop
```

### Step 3: Set up the Vault password

```bash
cp .vault-pass.example .vault-pass
echo "your-test-vault-password" > .vault-pass
```

### Step 4: Run each section in order, capturing output

For each section, use the `capture.sh` helper. It wraps your command in the Linux `script` utility, which records the entire terminal session including ANSI colors and timing.

```bash
# Section 1.4 — preflight check
./docs/captures/capture.sh section-1.4-preflight \
    ansible-playbook preflight/check.yml

# Section 2.1 — web tier
./docs/captures/capture.sh section-2.1-web-tier \
    ansible-playbook playbooks/02-web-tier.yml

# Section 2.2 — roles refactor
./docs/captures/capture.sh section-2.2-roles-refactor \
    ansible-playbook playbooks/03-web-tier-with-roles.yml

# Section 2.3 — windows management host
./docs/captures/capture.sh section-2.3-windows-mgmt \
    ansible-playbook playbooks/04-windows-mgmt.yml

# Section 3.1 — cross-platform hardening
./docs/captures/capture.sh section-3.1-hardening \
    ansible-playbook playbooks/05-harden.yml

# Section 3.2 — vault (set up vault first, then re-run the windows playbook)
# Before this capture: create inventory/group_vars/windows/vault.yml and
# encrypt it. See LAB-3.2.md for the procedure.
./docs/captures/capture.sh section-3.2-vault \
    ansible-playbook playbooks/04-windows-mgmt.yml

# Section 3.3 — rolling deployment
# Before this capture: update playbooks/03-web-tier-with-roles.yml to
# target 'webservers' instead of 'web1', then run it against web2 first.
./docs/captures/capture.sh section-3.3-rolling-deploy \
    ansible-playbook playbooks/06-rolling-deploy.yml

# Section 4.3 — capstone (full site.yml run)
./docs/captures/capture.sh section-4.3-capstone \
    ansible-playbook playbooks/site.yml
```

Each capture writes a file to `docs/captures/<name>.txt`. The file contains the full terminal session, including the command you ran, the output, and the exit code.

### Step 5: Verify each capture

After each capture, open the file and look for:

- The expected number of tasks executed
- A "PLAY RECAP" line showing `ok=N changed=N failed=0 unreachable=0`
- No unexpected warnings or errors
- Output that makes sense as a teaching reference (no secrets, no weird stack traces)

If a capture has problems, fix the underlying playbook issue and re-capture. **Do not ship captures with errors as "expected output."**

### Step 6: Replace the placeholders

For each successfully captured section, delete the corresponding `.txt.placeholder` file:

```bash
rm docs/captures/section-1.4-preflight.txt.placeholder
rm docs/captures/section-2.1-web-tier.txt.placeholder
# ...etc
```

### Step 7: Update the captures index

Edit `docs/captures/README.md` and update the table at the top — fill in your name and the date for each capture.

### Step 8: Commit

```bash
git add docs/captures/
git commit -m "Capture pass: <date>, <your-name>"
git push
```

### Step 9: Tear down the capture lab

```bash
cd provisioning/azure
ansible-playbook teardown.yml -e "purpose=capture-pass"
```

## What if a capture has secrets in it?

If output contains anything sensitive (real passwords, tokens, IPs that shouldn't be public), redact before committing. The Vault section is the most likely place this happens — if a `debug` task accidentally prints a vaulted variable, it'll be in the capture.

Quick redaction with sed:

```bash
sed -i 's/the-real-secret/REDACTED/g' docs/captures/section-3.2-vault.txt
```

For IP addresses (the public IP of the capture lab's control node will appear in some output), redact those too:

```bash
sed -i 's/20\.42\.[0-9]*\.[0-9]*/PUBLIC.IP.REDACTED/g' docs/captures/*.txt
```

## Re-capturing after code changes

If you change a playbook in a way that affects its output (renamed tasks, added tasks, changed module behavior), re-capture that section. Stale captures are worse than no captures because they actively mislead attendees who are using them as a reference.

The rule: **if you'd update the playbook for the workshop, update the capture for the workshop.**

## A note on terminal width

The `capture.sh` helper sets `COLUMNS=120` before running. This keeps captures consistent regardless of your terminal width. Don't override this — attendees viewing captures on smaller terminals will get wrapped output that's still readable.

## A note on timing data

The `script` utility records timing data as a side file (`<name>.timing`). The `capture.sh` script writes only the text output by default, since timing files aren't useful as a learning reference. If you want to *replay* a capture (using `scriptreplay`) for any reason, re-run with `capture.sh --with-timing` to get both files.
