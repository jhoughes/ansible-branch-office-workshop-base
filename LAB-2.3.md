# Section 2.3 — PowerShell + Windows Automation

> **Duration:** 20 minutes
> **Presenter:** Mike (from stage) + Joe (on the floor)
> **Your goal:** Watch Ansible — running on a Linux control node — install Windows software, manage Windows users and groups, create an SMB share, and run your own PowerShell script with structured output. Then customize it.

## Why this section exists

If you're a Windows admin, the pitch for Ansible has probably always sounded a little off: "it's a Linux automation tool that also kind of works on Windows." That framing undersells it badly. Ansible's Windows support is a first-class citizen of the platform — and once you see it work, the "I have to learn DSC or hand-roll PowerShell remoting from scratch" alternatives start to look quite tedious.

This section makes the case visually. You're going to watch your Linux control node, over WinRM, install real recognizable Windows software via Chocolatey, manage Windows users and groups using familiar concepts, configure an SMB share, and run a custom PowerShell script you wrote — capturing its structured output back as an Ansible variable.

By the end, you'll have a `windows-mgmt` role that does for Windows what the `webserver` role from section 2.2 does for Linux: a clean, idempotent, parameterizable unit of configuration.

---

## What you'll do in this section

1. Look at the windows-mgmt role's structure (it mirrors the webserver role from 2.2)
2. Run the role against mgmt1 — watch Chocolatey install four packages, create users, create the share, run your PowerShell
3. RDP to mgmt1 (using the port forward from section 1.4) and see the changes with your own eyes
4. Customize the role: add a Chocolatey package, add a user, see it apply
5. Read the custom PowerShell script and understand the win_powershell pattern

---

## Step 1 — Look at the role

```bash
cd ~/workshop
tree roles/windows-mgmt/
```

You should see the same structure as the `webserver` role from section 2.2, with a few additions:

```
roles/windows-mgmt/
├── defaults/
│   └── main.yml          ← list of Chocolatey packages, group name, users, share details
├── files/
│   └── inventory-report.ps1  ← the custom PowerShell script we'll run
├── handlers/
├── meta/
│   └── main.yml
└── tasks/
    └── main.yml          ← the seven steps that configure mgmt1
```

**Open `roles/windows-mgmt/tasks/main.yml`** and skim it. You'll see seven labeled steps:

1. Install Chocolatey itself (idempotent — skipped if already there)
2. Install admin tools via Chocolatey (the moment that lands)
3. Create a local group (BranchOfficeIT)
4. Create local users (alice.jones, bob.smith) and add them to the group
5. Create an SMB share with full access for the group
6. Open the firewall for SMB
7. Run a custom PowerShell inventory script and capture the output

**Open `roles/windows-mgmt/defaults/main.yml`** to see the variables. The Chocolatey package list (VS Code, Notepad++, 7-Zip, PowerShell 7) is at the top — you'll customize this in step 4.

**Open `roles/windows-mgmt/files/inventory-report.ps1`** — this is just a regular PowerShell script. Nothing Ansible-specific about it. It returns a hashtable of system info as its last expression. The `win_powershell` module captures that hashtable and makes each key available as a property of the registered variable.

---

## Step 2 — Run the role against mgmt1

```bash
ansible-playbook playbooks/04-windows-mgmt.yml
```

**Heads up:** the first run takes 5-10 minutes because Chocolatey downloads and installs four real packages. Don't worry — Mike is going to keep narrating from the front while it runs, and your terminal will keep updating.

**Expected output** (abbreviated, first run):

```
PLAY [Configure the branch office Windows management host] *********************

TASK [Gathering Facts] *********************************************************
ok: [mgmt1]

TASK [windows-mgmt : Install Chocolatey package manager] ***********************
changed: [mgmt1]

TASK [windows-mgmt : Install admin tools via Chocolatey] ***********************
changed: [mgmt1]

TASK [windows-mgmt : Create the branch office IT group] ************************
changed: [mgmt1]

TASK [windows-mgmt : Create local user accounts for branch office IT staff] ****
changed: [mgmt1] => (item=alice.jones)
changed: [mgmt1] => (item=bob.smith)

TASK [windows-mgmt : Ensure the share directory exists] ************************
changed: [mgmt1]

TASK [windows-mgmt : Create the branch office SMB share] ***********************
changed: [mgmt1]

TASK [windows-mgmt : Allow inbound SMB through Windows Firewall] ***************
changed: [mgmt1]

TASK [windows-mgmt : Gather a custom inventory report from mgmt1] **************
changed: [mgmt1]

TASK [windows-mgmt : Show the inventory report] ********************************
ok: [mgmt1] =>
  msg:
  - 'Branch office mgmt1 inventory report:'
  - '  hostname:        mgmt1'
  - '  os version:      Microsoft Windows Server 2022 Standard'
  - '  installed RAM:   8.0 GB'
  - '  CPU cores:       2'
  - '  uptime (hours):  2.4'
  - '  installed apps:  47'
  - '  local accounts:  6'
  - '  SMB shares:      1'

PLAY RECAP *********************************************************************
mgmt1                      : ok=10   changed=8    unreachable=0    failed=0
```

**The two things to watch for:**

1. **The Chocolatey install task** is where most of the time goes. You're watching VS Code (~150 MB), Notepad++ (~5 MB), 7-Zip (~2 MB), and PowerShell 7 (~100 MB) get downloaded and installed on the Windows host. By a Linux control node. Over WinRM.
2. **The custom inventory report at the end** is *your PowerShell script* running on the Windows host, returning a hashtable, with that hashtable's contents pulled into Ansible and rendered into a debug message. You wrote PowerShell, Ansible orchestrated it.

---

## Step 3 — RDP to mgmt1 and see the changes

You should still have terminal 3 from section 1.4 running the SSH port forward to mgmt1's RDP. If your RDP session is still open, switch to it. If not, open a fresh RDP session to `localhost:13389` with `workshop_admin` and the password from your card.

**Things to look at on the Windows desktop:**

1. **Start menu → All apps.** You should see VS Code, Notepad++, 7-Zip, and PowerShell 7 all listed. Try opening one — they're real, they work.

2. **Start menu → "Computer Management" → Local Users and Groups → Users.** You should see `alice.jones` and `bob.smith` in the user list.

3. **Computer Management → Local Users and Groups → Groups.** You should see `BranchOfficeIT`. Double-click it — alice and bob are members.

4. **File Explorer → This PC.** Open the address bar and type `\\localhost\BranchOfficeShared`. You should see an empty share — the directory exists, the SMB share is published, and Windows can browse it.

**Take a moment to appreciate this.** Every one of those things would normally be a 3-minute manual click-through-wizard task. You did them all in one playbook run, and you can do them again in 10 seconds against a hundred more machines.

---

## Step 4 — Customize the role

Roles are reusable when you can override their defaults. Try it.

Edit `playbooks/04-windows-mgmt.yml` and add a vars block to override the Chocolatey package list:

```yaml
---
- name: Configure the branch office Windows management host
  hosts: mgmt1
  gather_facts: true

  vars:
    windows_mgmt_chocolatey_packages:
      - vscode
      - notepadplusplus
      - 7zip
      - powershell-core
      - sysinternals       # NEW! Mark Russinovich's classic toolkit
      - git                # NEW! version control
      - putty              # NEW! the iconic SSH client (yes, on Windows)

  roles:
    - windows-mgmt
```

Save and run:

```bash
ansible-playbook playbooks/04-windows-mgmt.yml
```

**Expected output** (relevant tasks):

```
TASK [windows-mgmt : Install admin tools via Chocolatey] ***********************
changed: [mgmt1]
```

Watch the task — you'll see Chocolatey install only the *new* packages (sysinternals, git, putty). The four existing packages (vscode, notepadplusplus, 7zip, powershell-core) are already present, so Chocolatey skips them. **win_chocolatey is idempotent at the package level**, not just at the task level.

After the run completes, RDP back to mgmt1 and confirm the new tools are in the Start menu. You just added three packages by editing a YAML list and re-running one command.

> **Reset before continuing:** remove the `vars:` block from the playbook (or just remove the three new packages), so the lab is in a known state for section 3.1.

### Troubleshooting step 4

| Symptom | Fix |
|---|---|
| `WARNING: Package "putty" was found, but Failed to install` | Network issue — Chocolatey couldn't reach its CDN. Re-run the playbook. |
| Task hangs for 10+ minutes | One of the package installs is genuinely slow. Be patient. If it doesn't move at all, Ctrl+C and re-run. |

---

## Step 5 — Look at the inventory-report.ps1 script

```bash
cat roles/windows-mgmt/files/inventory-report.ps1
```

Walk through what it does:

- Calls `Get-ComputerInfo` to grab system properties
- Calculates uptime from `Win32_OperatingSystem.LastBootUpTime`
- Counts installed apps by reading the registry (much faster than `Get-Package`)
- Counts local users with `Get-LocalUser`
- Counts non-admin SMB shares with `Get-SmbShare`
- Returns a hashtable as the last expression

**That's a regular PowerShell script.** Nothing Ansible-specific in it. You could run it standalone in PowerShell ISE and it would work the same way. Ansible's role here is purely to orchestrate: it ships the script to the host, runs it, and captures the output.

The `win_powershell` module's superpower is that it captures the script's last expression as the `.output` property of the registered variable. So in the role's tasks file:

```yaml
- name: Gather a custom inventory report from mgmt1
  ansible.windows.win_powershell:
    script: "{{ lookup('file', 'inventory-report.ps1') }}"
  register: inventory_report

- name: Show the inventory report
  ansible.builtin.debug:
    msg:
      - "  hostname: {{ inventory_report.output.Hostname }}"
      - "  CPU cores: {{ inventory_report.output.CPUCores }}"
      ...
```

The hashtable from PowerShell becomes a structured Ansible variable. **This is the bridge between the two ecosystems.** Your existing PowerShell scripts can become Ansible-driven inputs without rewriting them.

---

## End of section 2.3

You should now have:

- A working `windows-mgmt` role at `roles/windows-mgmt/`
- VS Code, Notepad++, 7-Zip, and PowerShell 7 installed on mgmt1
- Two local users (alice.jones, bob.smith) in the BranchOfficeIT group
- A working SMB share at `\\mgmt1\BranchOfficeShared`
- A working pattern for running your own PowerShell scripts via Ansible
- Personal experience with `win_chocolatey`, `win_user`, `win_group`, `win_share`, `win_firewall_rule`, and `win_powershell`

You're ready for section 3.1, which combines what you've built so far into a cross-platform hardening role.

## Stretch goals (if you finished early)

- Open `roles/windows-mgmt/files/inventory-report.ps1` and add another field. Maybe `DiskFreeGB` (using `Get-Volume`) or `RunningServiceCount` (using `Get-Service | Where Status -eq Running`). Re-run the playbook and watch your new field appear in the debug output.
- Try `ansible mgmt1 -m ansible.windows.win_shell -a "Get-Process | Sort-Object CPU -Descending | Select-Object -First 5"` from the control node. That's an ad-hoc PowerShell command across WinRM. Useful for one-off queries.
- Look at the Chocolatey package list at https://community.chocolatey.org/packages and add three packages of your choice to the role's defaults.

## Checkpoint

The complete state of the repo at the end of this section is in `checkpoints/section-2.3/`. To use it:

```bash
cd ~/workshop/checkpoints/section-2.3
ansible-playbook playbooks/04-windows-mgmt.yml
```

See `docs/captures/section-2.3-windows-mgmt.txt` for what a successful run looks like.
