# Instructor Setup — Pre-Workshop Checklist

> **This document is for Joe (and Mike, where noted).** It consolidates everything that has to be done *before* workshop day so the 4-hour workshop content can start cleanly at section 1.1.
>
> **Workshop attendees: you don't need this.** Your instructor handles all of this in advance. See `README.md` for the attendee-facing quick start.

This is the single canonical pre-workshop checklist. If you're tempted to put a "before workshop day" instruction anywhere else in the repo, put it here instead.

---

## Phase 1: One-time setup (do once, then never again)

These steps only need to happen the first time you ever run this workshop. Once they're done, they're done forever (until something breaks).

### 1.1 — Create the WinRM bootstrap GitHub Gist

The Azure Custom Script Extension fetches `winrm-bootstrap.ps1` from a URL — it can't read local files. The recommended hosting is a public GitHub Gist with a commit-pinned raw URL.

- [ ] Go to https://gist.github.com and create a **public** gist
- [ ] Single file named `winrm-bootstrap.ps1`
- [ ] Paste the full contents of `provisioning/azure/files/winrm-bootstrap.ps1`
- [ ] Click "Create public gist"
- [ ] On the gist page, click the **"Raw"** button on the file
- [ ] Copy the URL from the address bar — it should look like:
  ```
  https://gist.githubusercontent.com/USERNAME/GISTID/raw/COMMIT_SHA/winrm-bootstrap.ps1
  ```
- [ ] **Critical:** the URL must include the commit SHA. If it doesn't, you grabbed the "always-latest" form, which can silently break every attendee's provisioning if the gist gets edited. Get the commit-pinned form instead — it's the URL GitHub gives you when you click "Raw" on a specific revision.
- [ ] Update three files with this URL:
  - `provisioning/azure/roles/attendee-rg/defaults/main.yml` — the `winrm_bootstrap_script_url` variable
  - `provisioning/bicep/deploy-all.sh` — the `WINRM_SCRIPT_URL` variable
  - `provisioning/bicep/main.bicep` — the `winrmBootstrapScriptUrl` parameter default
- [ ] Commit and push

> **If you ever update the script:** edit the gist, get a new commit-pinned raw URL (the SHA changes), and update all three files. Don't forget any.

### 1.2 — Set up your Azure subscription

- [ ] Confirm your Azure subscription has at least $1000 of available credit
- [ ] Confirm you're using the right subscription:
  ```bash
  az account show
  az account set --subscription "<the-right-one>"
  ```
- [ ] **Quota requirements updated for 60 registered attendees** (event grew from 20 → 60 in registration). Run these to check current state:
  ```bash
  az vm list-usage --location westus2 --output table
  az network list-usages --location westus2 --output table
  ```

  Required vs. previously confirmed limits:

  | Quota | Need (60 attendees) | Previously verified | Action |
  |---|---|---|---|
  | Total Regional vCPUs (West US 2) | 400 | 335 | **⚠ Request increase to 400** |
  | Standard BS Family vCPUs (West US 2) | 400 | 200 | **⚠ Request increase to 400** |
  | Standard Bsv2 Family vCPUs (West US 2) | 400 (hedge) | 200 | **⚠ Request increase to 400** |
  | Standard Public IPv4 Addresses (West US 2) | 80 | 100 | ✅ Sufficient |
  | Virtual Networks | 65 | 1000 | ✅ Sufficient |

  > **File all three quota increases in one ticket** through portal.azure.com → Subscriptions → Usage + quotas → Request increase. Microsoft typically approves within an hour.

  > **Re-verify before each new workshop run** by running those `az` commands again. If the subscription gets shared with other projects between workshops, available headroom may shrink.

  > **Note on AMD variant:** Standard Basv2 Family vCPUs (the AMD-based variant of BSv2) is at the default 65. The workshop targets Intel-based BS family (`Standard_B2s` for Linux, `Standard_B2ms` for Windows), so this quota isn't relevant in practice. If you ever change `vm_size_linux` or `vm_size_windows` in `provisioning/azure/group_vars/all.yml` to an AMD SKU, request a Basv2 increase first.

- [ ] Register the compute and network providers (idempotent):
  ```bash
  az provider register --namespace Microsoft.Compute --wait
  az provider register --namespace Microsoft.Network --wait
  ```

> **Quotas that are usually fine but worth a quick eyeball if your subscription is shared with other projects:**
> - Resource groups per subscription (default 980) — each attendee gets one
> - Virtual Networks per region (default 1000) — one per attendee
> - Standard storage accounts per region (default 250) — managed disks don't count against this, so unlikely to bite

> **API rate limits to know about (not changeable):** Azure Resource Manager throttles at ~1200 writes/hour per subscription. The provisioning playbook with 5 parallel forks stays well under this. **Don't bump `provisioning_forks` above 5** or you can hit throttling errors during the run.

### 1.3 — Install Ansible and the Azure collection on your local machine

These are the tools you'll run the provisioning playbook with. Doesn't matter if you're on macOS, Linux, or WSL2 on Windows.

- [ ] Install Ansible (latest stable):
  ```bash
  # macOS
  brew install ansible

  # Ubuntu/Debian/WSL2
  sudo apt install ansible

  # Or via pip in a venv
  python3 -m venv ~/ansible-venv && source ~/ansible-venv/bin/activate && pip install ansible
  ```
- [ ] Install the Azure collection and its Python dependencies:
  ```bash
  ansible-galaxy collection install azure.azcollection
  pip install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements.txt
  ```
- [ ] Verify:
  ```bash
  ansible --version
  ansible-galaxy collection list azure.azcollection
  ```

### 1.4 — Install PowerShell 7+ for the card generator

The attendee card generator script is written in PowerShell (it's the right language for this audience and Mike maintains it).

- [ ] Install PowerShell 7+ if you don't have it:
  ```bash
  # macOS
  brew install --cask powershell

  # Ubuntu/Debian
  # See https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu

  # Windows
  # winget install Microsoft.PowerShell
  ```
- [ ] Verify:
  ```bash
  pwsh -Command '$PSVersionTable.PSVersion'
  ```

---

## Phase 2: Per-workshop setup (do this for each workshop run, ~1 week before)

### 2.1 — Find the conference network's egress IP

The Network Security Group on each attendee's lab will only allow inbound SSH from this IP (or these IPs). Without this, the lab is wide open to the internet.

- [ ] Email the conference network team OR ask the venue WiFi admin: "what is the public egress IP for the conference network?"
- [ ] Alternatively, the day before the workshop, get on the conference WiFi yourself and run:
  ```bash
  curl ifconfig.me
  ```
- [ ] Update `provisioning/azure/group_vars/all.yml`:
  - Find the `allowed_ssh_sources` variable
  - Replace `0.0.0.0/0` with the conference egress IP(s) in CIDR form
  - Example: `["203.0.113.42/32"]` for a single IP, or multiple entries if the venue has several
- [ ] If you can't get the conference egress IP in advance: leave `0.0.0.0/0` for now, but **plan to re-run `site.yml` from the venue on workshop morning** with the corrected value. The NSG update is fast (~30 seconds per attendee).

### 2.2 — Edit the attendee inventory

- [ ] Open `provisioning/azure/inventory/attendees.yml`
- [ ] Adjust the attendee count to match registered headcount + ~5 walk-up buffer
- [ ] Confirm the `instructor` entry is present (attendee number `99`) — this is Mike's demo lab for section 1.3

### 2.2.5 — Review the pinned Galaxy collection versions

The workshop's required Ansible Galaxy collections (`ansible.windows`, `community.windows`, `ansible.posix`, `community.general`) are pinned to specific versions in `requirements.yml` at the repo root. This ensures every attendee gets the same versions, and that the lab is reproducible months or years from now.

Before each workshop run, decide whether to bump the pinned versions:

- [ ] Open `requirements.yml`
- [ ] For each collection, visit `https://galaxy.ansible.com/<namespace>/<n>` (e.g., https://galaxy.ansible.com/ansible/windows) and check for newer stable releases
- [ ] If newer versions have shipped meaningful improvements or bugfixes, update the `version:` line
- [ ] If you bumped any versions, **the lab build / capture pass (step 2.6 below) is your validation that the new versions don't break anything.** Don't ship version bumps without re-capturing.
- [ ] If you didn't bump anything, no action — the existing pins are validated by the most recent capture pass.

> **Worth knowing:** Galaxy collections occasionally ship breaking changes in major-version bumps. If a collection went from 2.x to 3.x since the last workshop, treat the upgrade as risky and budget extra time for the capture pass to find anything that broke.

### 2.3 — Provision all attendee labs

- [ ] From `provisioning/azure/`, run:
  ```bash
  ansible-playbook site.yml
  ```
- [ ] This takes ~10-15 minutes per attendee, parallelized 5 at a time. For 60 attendees, plan on **2-3 hours wall clock**. Run this the morning BEFORE workshop day, not the morning of.

  > **Don't raise `provisioning_forks` above 5** to try to speed this up — Azure ARM throttles at ~1200 writes/hour per subscription and you'll hit it. Patience is the right answer here.
- [ ] Watch for any failures during the run. Re-run `site.yml` to fix them — the playbook is idempotent.
- [ ] After it finishes, the credentials CSV is at `provisioning/azure/attendee-credentials.csv`. **Treat this file as a secret** — it has every attendee's SSH password.

### 2.4 — Run the verify playbook

- [ ] From `provisioning/azure/`, run:
  ```bash
  ansible-playbook verify.yml
  ```
- [ ] Confirm every attendee shows ✓ for SSH, Bootstrap, Repo, Ansible, pywinrm, and win_ping
- [ ] Anything showing ✗ — re-run `site.yml --limit attendeeNN` for the affected attendee

### 2.5 — Generate the attendee cards

- [ ] From `provisioning/azure/`, run:
  ```bash
  pwsh ./generate-attendee-cards.ps1
  ```
- [ ] This produces `attendee-cards.html` — open it in a browser to preview
- [ ] Print using the browser's "Print to PDF" function, or print directly on a workshop printer
- [ ] Recommended: print on cardstock (heavier paper, easier to hand out and harder to lose)
- [ ] Cut along the page boundaries — each card is one page, designed to fold into a tent or stand on its own

### 2.6 — Run the lab build / capture pass

This is the workshop's integration test. Run every section's playbooks end-to-end against the instructor lab (attendee 99) and capture the terminal output. See `docs/captures/HOW-TO-CAPTURE.md` for the full protocol.

- [ ] SSH to the instructor control node:
  ```bash
  ssh attendee@<instructor-99-control-ip>
  ```
- [ ] For each section in `LAB-OVERVIEW.md`, run `./docs/captures/capture.sh <section-name> <command>` and verify the output
- [ ] If any section breaks, fix the underlying playbook before workshop day
- [ ] Replace the `.txt.placeholder` files in `docs/captures/` with the real captures
- [ ] Commit the captures

### 2.7 — Sync with Mike

- [ ] Walk Mike through the room layout, the dual-instructor coordination plan, and the section assignment table
- [ ] Confirm Mike has access to the instructor control node (attendee 99) for his section 1.3 demo
- [ ] Confirm Mike has the runbook (`docs/runbook.md`) and the lab guides
- [ ] Discuss the swap points and who's leading which section

---

## Phase 3: Day before the workshop

### 3.1 — Re-run verify

- [ ] Verify every attendee lab is still healthy:
  ```bash
  ansible-playbook verify.yml
  ```
- [ ] Anything that's broken: re-run `site.yml --limit attendeeNN` to fix

### 3.2 — Test from the venue network

If you can get to the venue the day before, do this. If not, do it as early as possible on workshop morning.

- [ ] Confirm the conference egress IP matches what you set in `allowed_ssh_sources`
- [ ] If different: update `group_vars/all.yml`, re-run `site.yml`, re-run `verify.yml`
- [ ] Test SSH from a laptop on the venue WiFi to one attendee's control node — confirm it works
- [ ] Test SSH port forwarding for both port 80 (web1) and port 3389 (mgmt1) — confirm both work end-to-end

### 3.3 — Print materials

- [ ] Print the attendee cards (cardstock recommended)
- [ ] Print the workshop's printed cheatsheets if you've made any
- [ ] Print 2-3 copies of the runbook for you and Mike to keep nearby

---

## Phase 4: Workshop day, before the session

### 4.1 — 60 minutes before

- [ ] Arrive at the room early
- [ ] Test projector and audio
- [ ] Pull up the workshop slides on the lectern laptop
- [ ] Pull up the instructor lab terminal on Mike's demo laptop (for section 1.3)
- [ ] SSH to the instructor control node, verify everything is reachable
- [ ] Open `LAB-1.4.md` so Mike can demo the SSH port forward setup live
- [ ] Lay out attendee cards at the door

### 4.2 — 15 minutes before

- [ ] Confirm with Mike who's leading section 1.1 (both of you co-presenting)
- [ ] Confirm the runbook is on both laptops
- [ ] Take a deep breath. Have water nearby. You're ready.

---

## Phase 5: After the workshop

### 5.1 — Tear down ALL attendee labs

This is the most important post-workshop step. Forgetting it is how a $300 workshop becomes a $1500 surprise bill.

- [ ] From `provisioning/azure/`, run:
  ```bash
  ansible-playbook teardown.yml
  ```
- [ ] Confirm at the prompt by typing `DELETE`
- [ ] Verify nothing remains:
  ```bash
  az group list -o table | grep workshop-att
  # should return nothing
  ```

### 5.2 — Securely delete the credentials file

- [ ] Shred the credentials CSV:
  ```bash
  shred -u provisioning/azure/attendee-credentials.csv
  ```

### 5.3 — Capture lessons learned

- [ ] Note any pain points, broken steps, or attendee questions for the next run
- [ ] File issues in the repo for anything that needs fixing
- [ ] Tag the repo with the conference name (e.g., `git tag pdsummit-2026 && git push --tags`)
