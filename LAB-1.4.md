# Section 1.4 — First Hands-On Lab Access

> **Duration:** 20 minutes
> **Presenter:** Joe (from stage) + Mike (on the floor)
> **Your goal:** By the end of this section, you will have proven to yourself that you can reach all three lab hosts in the modes you'll need for the rest of the workshop.

## What you'll do in this section

1. Take out your attendee card
2. SSH to your control node
3. Run the preflight playbook (the "you just ran Ansible" moment)
4. Set a Windows password variable so the inventory can talk to mgmt1
5. Set up an SSH port forward to reach web1 in your browser
6. Set up an SSH port forward to reach mgmt1 via RDP
7. Log into the Windows desktop and see it for real

When you're done, you'll be ready for section 2.1.

---

## Step 1 — Take out your attendee card

You received it at the door. It looks something like this:

```
Attendee 07
Building End-to-End Automation with Ansible
PowerShell & DevOps Summit 2026

Control node IP:         20.42.123.45
SSH username:            attendee
SSH password:            K7p2vQ8mN3rL
Windows admin user:      workshop_admin
Windows admin password:  aB3!xY9zM2pL7qR4!
Workshop Vault password: POWERSHELL&DEVOPS_SUMMIT_2026!

Workshop repository:
https://github.com/jhoughes/ansible-branch-office-workshop-base
```

**Your values will be different.** Every attendee gets a unique control IP and unique passwords. The Vault password is the same for everyone (and is also posted on a slide during section 3.2).

> **If you don't have a card:** raise your hand. Your instructor will bring you one.

---

## Step 2 — SSH to your control node

Open a terminal on your laptop:

- **macOS:** Terminal.app or iTerm
- **Linux:** your usual terminal
- **Windows 10+:** PowerShell, Windows Terminal, or `cmd` all have `ssh` built in
- **Chromebook:** the "Secure Shell Extension" from the Chrome Web Store

Then run (replace the IP with the one from your card):

```bash
ssh attendee@<YOUR-CONTROL-IP>
```

You'll be prompted for your SSH password. Paste it from your card (typing a 16-character random password is a recipe for frustration). Copy-paste is fine — this is a lab, not a nuclear launch code.

The first time you connect, SSH will ask about the host key fingerprint:

```
The authenticity of host '20.42.123.45 (20.42.123.45)' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press enter. You'll only see this prompt on the first connection.

After authentication, you should land at a prompt like:

```
attendee@control:~$
```

You're now logged into your control node. Everything else in this section happens from here.

### Troubleshooting step 2

| Symptom | What it means | Fix |
|---|---|---|
| `ssh: Connection refused` | The IP is wrong, OR the control node isn't running | Double-check the IP against your card. If it matches, raise your hand. |
| `Permission denied (publickey,password)` | The password was typed wrong | Paste it from the card. Watch for extra spaces at the end. |
| `Network is unreachable` | The conference WiFi isn't letting you out | Try again in 10 seconds. If it persists, use your phone's hotspot. |
| `ssh: command not found` | You're on very old Windows, or a stripped-down terminal | Try `cmd` instead of PowerShell, or install Git for Windows (which ships with `ssh`) |

---

## Step 3 — Run the preflight playbook

You're logged into control. The workshop repo is already cloned at `~/workshop`. Let's confirm the lab is alive:

```bash
cd ~/workshop
ansible-playbook preflight/check.yml
```

You'll see Ansible start up, run a few tasks, and print a summary. The whole thing takes about 30 seconds.

**What you just did:** you ran an Ansible playbook. The `preflight/check.yml` file pings two hosts (`web1` and `mgmt1`) and prints information about each one. You're already using the tool you came here to learn.

**Expected output** (the exact IPs will differ for your attendee number):

```
PLAY [Preflight — say hello to web1 (the Linux web server)] ********************

TASK [Gathering Facts] *********************************************************
ok: [web1]

TASK [Confirm web1 is reachable] ***********************************************
ok: [web1]

TASK [Show what web1 looks like] ***********************************************
ok: [web1] =>
  msg:
  - ✓ web1 is reachable
  -   hostname:     web1
  -   distribution: Ubuntu 22.04
  -   kernel:       5.15.0-xxx-azure
  -   IP address:   10.7.0.10

PLAY [Preflight — say hello to mgmt1 (the Windows host)] ***********************

TASK [Gathering Facts] *********************************************************
...
```

If you see **two ✓ marks** (one for `web1`, one for `mgmt1`) and a final welcome message, preflight passed. Move to step 4.

### Troubleshooting step 3

| Symptom | What it means | Fix |
|---|---|---|
| `FAILED! => {"msg": "Failed to connect to the host via ssh"}` for web1 | web1 isn't reachable from control | Raise your hand. Your lab may need attention. |
| `FAILED! => {"msg": "winrm send_input failed"}` for mgmt1 | The Windows password in `inventory/group_vars/windows.yml` hasn't been updated yet | This is expected on first run — move to step 4 to fix it |
| `command not found: ansible-playbook` | You're not in `~/workshop`, or the control node's cloud-init didn't finish | `cd ~/workshop` first. If that doesn't help, raise your hand. |

> **Note:** On your very first preflight run, the `mgmt1` play will **fail** because the Windows admin password is still set to a placeholder. That's expected. Step 4 is where we fix it.

---

## Step 4 — Set the Windows admin password

The workshop inventory has a placeholder password for the Windows host. You need to replace it with the one from your card.

Open the file in an editor on the control node:

```bash
nano inventory/group_vars/windows.yml
```

(or use `vim` or `vi` if you prefer — they're all installed)

Find this line near the bottom:

```yaml
ansible_password: REPLACE_ME_WITH_PASSWORD_FROM_YOUR_CARD
```

Replace `REPLACE_ME_WITH_PASSWORD_FROM_YOUR_CARD` with the **Windows admin password** from your card (the one labeled "Windows admin password" — NOT the SSH password, NOT the Vault password).

Save and exit:
- `nano`: `Ctrl+O`, `Enter`, then `Ctrl+X`
- `vim`: press `Esc`, then type `:wq` and press `Enter`

Re-run preflight to confirm both hosts are now reachable:

```bash
ansible-playbook preflight/check.yml
```

This time you should see **two ✓ marks** — one for `web1` and one for `mgmt1`. The welcome message at the end should say you're ready for the next step.

### Troubleshooting step 4

| Symptom | What it means | Fix |
|---|---|---|
| Still failing on mgmt1 after editing | The password wasn't saved, OR has a typo | Re-open the file and compare character-by-character against your card |
| `FAILED! => {"msg": "basic: 401"}` for mgmt1 | Wrong password | Check the card again — make sure you copied the Windows password, not the SSH password |
| `FAILED! => {"msg": "certificate verify failed"}` | Cert validation somehow re-enabled | Should never happen — raise your hand |

> **Security note:** Editing a password directly into a file isn't how you'd do this in production — you'd use Ansible Vault (which you'll learn in section 3.2) or environment variables. For this workshop's lab, the shortcut is acceptable because the password is ephemeral and the file is only on your control node. Don't build the habit of committing passwords to files in real work.

---

## Step 5 — Set up an SSH port forward to web1

web1 is a Linux web server on your private network — you can't reach it directly from your laptop because it has no public IP. But you can reach it **through** your control node using SSH port forwarding.

Here's the idea: we'll tell SSH "any traffic I send to `localhost:8080` on my laptop, tunnel it through the SSH connection to `10.NN.0.10:80` (web1's internal IP and port)." Then we open `http://localhost:8080` in the browser and see web1.

**Open a second terminal window on your laptop.** Leave the first one logged into the control node — don't close it.

In the **second** terminal, run (replace `<YOUR-CONTROL-IP>` with your card's IP, and `NN` with your attendee number):

```bash
ssh -L 8080:10.NN.0.10:80 attendee@<YOUR-CONTROL-IP>
```

For example, attendee 7 with control IP `20.42.123.45` would run:

```bash
ssh -L 8080:10.7.0.10:80 attendee@20.42.123.45
```

The SSH session will start. Enter your SSH password from the card. The session will land at a prompt, just like in step 2.

**Leave this terminal window open and alone.** The port forward only works as long as this SSH session is alive. If you close the terminal, the forward dies.

Now open a web browser on your laptop and go to:

```
http://localhost:8080
```

**What you should see right now:** a default nginx "Welcome to nginx!" page, OR a connection error (`ERR_CONNECTION_REFUSED`). Both are fine!

- **nginx welcome page:** nginx is running on web1 with a default config. This will happen if you're re-running this section or your lab was pre-built with nginx installed.
- **Connection refused:** nginx isn't running yet. This is the *expected* state at the start of the workshop — you'll install it in section 2.1.

**You're not trying to see a real web page here.** You're proving that the port forward works. Either response from the browser is proof of success — the browser reached `localhost:8080`, SSH tunneled it to web1, and web1 either responded (success) or refused (also success, because that means the tunnel got through).

### Troubleshooting step 5

| Symptom | What it means | Fix |
|---|---|---|
| `bind: Address already in use` | You already have something on port 8080 | Try a different local port: `ssh -L 8888:10.NN.0.10:80 ...` and use `http://localhost:8888` |
| Second SSH session hangs immediately | The port forward command is blocking on auth — check if it's asking for a password | Look carefully at the terminal for a password prompt |
| Browser shows nothing / spins forever | The SSH session in the second terminal died or was closed | Re-open the second terminal and re-run the `ssh -L` command |
| `channel 3: open failed: connect failed` in the SSH window | The port forward can't reach web1:80 from the control node | Could mean web1 is down. Raise your hand. |

---

## Step 6 — Set up an SSH port forward to mgmt1's RDP

Same idea, different port and different host. We'll forward `localhost:13389` on your laptop to `10.NN.0.20:3389` (mgmt1's internal IP and the standard RDP port).

**Open a third terminal window on your laptop.** You should now have three terminals open:

1. Terminal 1: SSH'd to control (step 2) — still active
2. Terminal 2: SSH'd to control with the web forward (step 5) — still active
3. Terminal 3: the new one — empty, on your laptop

In terminal 3, run:

```bash
ssh -L 13389:10.NN.0.20:3389 attendee@<YOUR-CONTROL-IP>
```

Enter your SSH password. The session will land at a control node prompt. Leave this window open.

> **Why `13389` and not `3389`?** Some operating systems (especially Windows) refuse to let non-administrator processes bind to ports below 1024 or the standard RDP port 3389. Using `13389` avoids any permission drama. You'll connect your RDP client to `localhost:13389` in the next step.

### Troubleshooting step 6

Same as step 5, plus:

| Symptom | Fix |
|---|---|
| You already used port 13389 for something else | Pick another high port: `ssh -L 23389:10.NN.0.20:3389 ...` and use `localhost:23389` in the RDP client |

---

## Step 7 — RDP into mgmt1

**Open your RDP client:**

- **Windows:** Start menu → "Remote Desktop Connection" (or `mstsc.exe`)
- **macOS:** "Windows App" (formerly "Microsoft Remote Desktop") from the App Store — free
- **Linux:** `remmina`, `xfreerdp`, or `freerdp` — one of them will already be installed
- **Chromebook:** "Chrome Remote Desktop" doesn't help here. Install "Jump Desktop" or use the Android RDP client from the Play Store.

**Connect to:**

```
Computer: localhost:13389
```

(or whatever local port you chose in step 6)

When prompted for credentials:

- **Username:** `workshop_admin`
- **Password:** the Windows admin password from your card (the same one you put in `windows.yml` in step 4)

You may see a warning about certificate trust — that's expected, because the Windows host has a self-signed certificate. Click "Yes" / "Continue" / "Connect anyway".

**You should land on a Windows Server 2022 desktop.** Take a moment to appreciate what just happened: your Ansible playbook on the control node is about to manage *this* desktop via WinRM, and you're looking at the machine you're going to automate.

**Poke around briefly:**
- Open PowerShell as administrator (right-click the Start menu → Windows PowerShell (Admin))
- Run `hostname` — you should see `mgmt1`
- Run `Get-LocalUser` — you'll see `workshop_admin` and a few built-in accounts
- These are the same things your Ansible playbook will see and manage in section 2.3

**Leave the RDP window open for now.** You don't need it for section 2.1, but you'll want it back in section 2.3 to see changes happen in real time as you run Ansible playbooks against it.

### Troubleshooting step 7

| Symptom | Fix |
|---|---|
| RDP client says "can't connect" | Check terminal 3 — the `ssh -L 13389:...` session must be active |
| "The logon attempt failed" | Wrong password — compare against the Windows admin password on your card |
| Certificate warning blocks connection | Click through it — self-signed is expected |
| Windows login screen but no desktop | Be patient — first login on a fresh VM can take 30-60 seconds |

---

## End of section 1.4

You should now have:

- **Terminal 1**: SSH'd to control, at a prompt, ready to run playbooks
- **Terminal 2**: SSH tunnel for web1 (port 8080) — running quietly in the background
- **Terminal 3**: SSH tunnel for mgmt1 RDP (port 13389) — running quietly in the background
- **Browser**: `http://localhost:8080` reaches web1 (even if it shows an error or default page)
- **RDP client**: connected to `localhost:13389`, looking at the Windows desktop

**If all of that is true, you're ready for section 2.1.** If any of it isn't, raise your hand — Mike is on the floor specifically to catch stragglers during this section, and no one moves to 2.1 until the room is ready.

## Stretch goals (if you finished early)

- Open a 4th terminal, `ssh` to control, and from there `ssh web1` to hop into the Linux web server directly. This is the attendee's-eye view of a jump-box topology — the control node is your way into everything else.
- On the mgmt1 RDP session, open Server Manager. Take a screenshot of it for your "before" shot — you'll want to compare it to the "after" shot in section 2.3 once Ansible has reconfigured the machine.
- Read `LAB-2.1.md` so you're ready to go when Joe starts the next section.

## Checkpoint

If you got lost or your lab is in an unknown state, the complete expected state of the repo at the end of this section is in `checkpoints/section-1.4/`. Your control node is the "stock" lab state with the Windows password set — there's nothing new in the filesystem for you to catch up on, so the checkpoint is empty of changes by design. The files in `checkpoints/section-1.4/` are just a marker that you made it through.

See the captured output in `docs/captures/section-1.4-preflight.txt` for what a successful preflight run looks like end-to-end.
