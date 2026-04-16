# Section 3.1 — Security Hardening As Code

> **Duration:** 20 minutes
> **Presenter:** Joe (from stage) + Mike (on the floor)
> **Your goal:** Apply a single hardening role that handles both your Linux web server AND your Windows management host, structured around a 9-item baseline checklist.

## Why this section exists

Every sysadmin in the room knows the drill: a new server gets stood up, somebody hands you a security checklist, and you spend an hour clicking through SSH config edits, firewall rules, password policies, and audit settings. Multiply by every server in your environment. Multiply again by every audit cycle. This is the work that *should* be automated, but rarely is — usually because the team that owns the servers and the team that owns the security baseline don't share tooling.

Ansible solves this by letting both teams agree on a checklist, then expressing the checklist as code. The checklist is reviewable. The code is version-controlled. The application is repeatable. Drift gets caught and fixed automatically every time the playbook runs.

This section gives you a working version of that pattern, structured around Geerling's "First 5 Minutes Server Security" 9-item checklist (from *Ansible for DevOps* chapter 11 and Ansible 101 episode 9). The same 9 items get applied — in OS-appropriate ways — to both your Linux web server and your Windows management host.

## What you'll do in this section

1. Look at the cross-platform dispatcher pattern (one role, two OS families)
2. Read the 9-item checklist and see how each item maps to a task on each OS
3. Run the hardening playbook against both `web1` and `mgmt1` in one command
4. Verify the changes (Linux SSH config, Windows registry) by hand
5. Re-run to see idempotency — the second run should report `changed=0`

---

## Step 1 — Look at the dispatcher pattern

```bash
cd ~/workshop
tree roles/hardening/
```

You should see:

```
roles/hardening/
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml
├── meta/
│   └── main.yml
└── tasks/
    ├── main.yml          ← the dispatcher
    ├── linux.yml         ← Linux 9-item baseline
    └── windows.yml       ← Windows 9-item baseline
```

**Open `roles/hardening/tasks/main.yml`** — it's the smallest tasks file in the workshop:

```yaml
- name: Apply Linux hardening tasks
  ansible.builtin.include_tasks: linux.yml
  when: ansible_facts.os_family in ['Debian', 'RedHat']

- name: Apply Windows hardening tasks
  ansible.builtin.include_tasks: windows.yml
  when: ansible_facts.os_family == 'Windows'
```

**That's the whole pattern.** The role's `main.yml` looks at `ansible_facts.os_family` (which Ansible gathered automatically when the playbook started) and includes the appropriate OS-specific task file. The same role can be applied to any host in any inventory and it'll do the right thing.

This is the canonical pattern for cross-platform roles in Ansible. Roles for monitoring agents, log shippers, configuration management agents, and corporate baselines all use the same dispatcher → OS-specific files structure.

---

## Step 2 — Walk through the 9-item checklist

Open `roles/hardening/tasks/linux.yml` and `roles/hardening/tasks/windows.yml` in two terminals (or in two editor windows side by side). Each file is structured around the same 9-item checklist, with comments numbering each item:

| # | Item | Linux implementation | Windows implementation |
|---|---|---|---|
| 1 | Use secure encrypted communications | SSH config lockdown (X11 off, MaxAuthTries, ClientAlive) | Require RDP NLA |
| 2 | Disable root remote login | `PermitRootLogin no` in sshd_config | (Lab note: in production, rename and disable built-in Administrator) |
| 3 | Remove unused software | apt remove telnet, rsh-client, talk | win_optional_feature absent: SMBv1, TelnetClient |
| 4 | Apply principle of least privilege | Restrict log file permissions | Account lockout policy (5 attempts, 15 min) |
| 5 | Automate updates | unattended-upgrades + apt config | Configure Windows Update auto-download (no auto-install) |
| 6 | Configure a firewall | ufw default deny in / allow out, allow 22 + 80 | Ensure all 3 Windows Firewall profiles enabled |
| 7 | Ensure log files are populated/rotated | Ensure rsyslog is running | Enable logon auditing (success + failure) |
| 8 | Monitor login attempts | Install + enable fail2ban | Min password length 12, complexity required |
| 9 | Mandatory access control | Confirm AppArmor is enabled | UAC at highest level (registry settings) |

**One thing to call out specifically — look at the SSH config tasks in `linux.yml`:**

```yaml
- name: "Item 1: Update SSH configuration to be more secure"
  ansible.builtin.lineinfile:
    dest: /etc/ssh/sshd_config
    ...
    validate: 'sshd -t -f %s'
```

The `validate:` parameter is the most important pattern in this entire role. It tells Ansible to run `sshd -t` on the new config file BEFORE writing it. If `sshd -t` fails (typo, invalid syntax, anything), the file is never updated. Without this, a single bad regex could lock you out of every host you just "hardened."

This is the pattern Jeff Geerling famously skipped on camera in Ansible 101 episode 9, locking himself out of his demo VM mid-stream. Don't be Jeff Geerling on this one. Always use `validate:` when editing config files for services you depend on to stay reachable.

---

## Step 3 — Run the hardening playbook

```bash
ansible-playbook playbooks/05-harden.yml
```

This applies the role to **every host in the `branch_office` inventory group**, which is `web1`, `web2` (when it exists), and `mgmt1`. The playbook is short:

```yaml
- name: Apply baseline hardening to all branch office hosts
  hosts: branch_office
  gather_facts: true
  roles:
    - hardening
```

**Heads up:** the first run takes 2-4 minutes because it installs unattended-upgrades and fail2ban on Linux, and applies a dozen registry / security policy changes on Windows. The terminal will be busy.

**Expected output** (abbreviated):

```
PLAY [Apply baseline hardening to all branch office hosts] *********************

TASK [Gathering Facts] *********************************************************
ok: [web1]
ok: [mgmt1]
fatal: [web2]: UNREACHABLE!  ← expected — web2 doesn't exist yet, comes online in section 3.3

TASK [hardening : Apply Linux hardening tasks] *********************************
included: linux.yml for web1

TASK [hardening : Apply Windows hardening tasks] *******************************
included: windows.yml for mgmt1

TASK [hardening : Item 1: Update SSH configuration to be more secure] **********
changed: [web1] => (item={'regexp': '^#?PasswordAuthentication', ...})
changed: [web1] => (item={'regexp': '^#?X11Forwarding', ...})
changed: [web1] => (item={'regexp': '^#?MaxAuthTries', ...})
changed: [web1] => (item={'regexp': '^#?ClientAliveInterval', ...})

TASK [hardening : Item 1: Require Network Level Authentication for RDP] ********
changed: [mgmt1]

... [many more tasks across both OSes] ...

RUNNING HANDLER [hardening : Restart sshd] *************************************
changed: [web1]

PLAY RECAP *********************************************************************
mgmt1                      : ok=15   changed=12   unreachable=0    failed=0
web1                       : ok=18   changed=14   unreachable=0    failed=0
web2                       : ok=0    changed=0    unreachable=1    failed=0
```

The `web2` UNREACHABLE is expected and harmless — that host doesn't exist until section 3.3. Ansible reports it but the play still succeeds for the hosts that DO exist.

---

## Step 4 — Verify the changes by hand

This is the "trust but verify" moment. The playbook reported `changed`. Let's confirm what actually happened.

### On the Linux side (web1):

In your control terminal, hop to web1:

```bash
ssh web1
```

Check the SSH config:

```bash
sudo grep -E "^(PermitRootLogin|MaxAuthTries|X11Forwarding|ClientAliveInterval)" /etc/ssh/sshd_config
```

You should see:

```
PermitRootLogin no
MaxAuthTries 3
X11Forwarding no
ClientAliveInterval 300
```

Check that fail2ban is running:

```bash
sudo systemctl status fail2ban | head -5
```

Should show `active (running)`.

Exit back to control:

```bash
exit
```

### On the Windows side (mgmt1):

Switch to your RDP session to mgmt1 (the one you opened in section 1.4 step 7).

Open PowerShell as administrator and check the account lockout policy:

```powershell
net accounts
```

You should see `Lockout threshold: 5` and `Lockout duration (minutes): 15`.

Check that SMBv1 is disabled:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol | Select-Object State
```

Should show `State : Disabled`.

Check that all three firewall profiles are enabled:

```powershell
Get-NetFirewallProfile | Select-Object Name, Enabled
```

All three (Domain, Private, Public) should show `Enabled : True`.

---

## Step 5 — Re-run for idempotency

```bash
cd ~/workshop
ansible-playbook playbooks/05-harden.yml
```

**Expected output** (the magic moment):

```
PLAY RECAP *********************************************************************
mgmt1                      : ok=15   changed=0    unreachable=0    failed=0
web1                       : ok=18   changed=0    unreachable=0    failed=0
web2                       : ok=0    changed=0    unreachable=1    failed=0
```

`changed=0` on both hosts. Every task ran, every desired state was confirmed, nothing needed to be modified. The sshd handler did NOT fire because no notifying task changed.

**This is the property that makes hardening-as-code work in production.** You can run this playbook on a schedule (every hour, every day, after every deploy) and it'll continuously enforce the baseline. Drift gets caught and corrected automatically. If someone manually edits sshd_config to weaken something, the next playbook run reverts it.

---

## End of section 3.1

You should now have:

- A `hardening` role at `roles/hardening/` with the cross-platform dispatcher pattern
- web1 hardened: SSH locked down, root login disabled, fail2ban running, ufw configured, AppArmor confirmed, automatic updates enabled
- mgmt1 hardened: RDP NLA required, SMBv1 disabled, account lockout policy set, password complexity required, UAC at highest level, firewall profiles enabled, audit policy configured

You're ready for section 3.2, where we'll look at the Windows password placeholder you've been editing into `windows.yml` for the last hour and make it disappear properly using Ansible Vault.

## Stretch goals

- Open `/etc/ssh/sshd_config` on web1 with `sudo nano` and intentionally introduce a typo (e.g., `PermitRootLgoin no`). Save it, then re-run `playbooks/05-harden.yml`. Watch the validate clause catch the issue gracefully — the file gets updated correctly because the bad version was caught at validation. (Ansible's `lineinfile` reverts and reports.)
- Look at https://github.com/dev-sec/ansible-collection-hardening for a production-grade cross-platform hardening collection. Compare its OS dispatcher to ours — same idea, much more thorough.
- Add a 10th hardening item to both OS task files. Suggestions: enable swap encryption on Linux, enable BitLocker policy on Windows.

## Checkpoint

Complete state in `checkpoints/section-3.1/`. To use it:

```bash
cd ~/workshop/checkpoints/section-3.1
ansible-playbook playbooks/05-harden.yml
```

See `docs/captures/section-3.1-hardening.txt` for what a successful run looks like.
