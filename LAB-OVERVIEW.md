# Lab Overview

This is the index for all the hands-on lab guides in the workshop. Each section has its own `LAB-X.Y.md` file with step-by-step instructions, expected output, and troubleshooting notes.

## How to use the lab guides

1. **Follow along during the section.** The instructor will walk through the concepts, then point you at the lab guide for the hands-on portion.
2. **Work at your own pace within the section.** The lab time is yours. If you finish early, look for stretch goals at the bottom of each guide.
3. **If you fall behind, use the checkpoint directories.** Each section has a `checkpoints/section-X.Y/` directory with a complete, working snapshot of all the code as it should exist at the end of that section. If you get lost, you can `cd` into the checkpoint and you're caught up.
4. **Compare your output to the expected output.** Each lab guide shows what successful runs should look like. If your output is different, that's a clue.

## Lab guides by section

> **The 4-hour clock starts at section 1.1 with the welcome.** Sections 1.1 through 1.3 are presenter-driven (no attendee laptops required). Section 1.4 is the first time attendees touch their lab — your instructor walks you through SSH, port forwards, and RDP access.

| Section | Topic | Lab file | Checkpoint |
|---|---|---|---|
| 1.4 | First hands-on lab access (preflight + port forwards + RDP) | `LAB-1.4.md` | `checkpoints/section-1.4/` |
| 2.1 | First real playbook (Linux web tier) | `LAB-2.1.md` | `checkpoints/section-2.1/` |
| 2.2 | Refactor into roles | `LAB-2.2.md` | `checkpoints/section-2.2/` |
| 2.3 | Windows + PowerShell | `LAB-2.3.md` | `checkpoints/section-2.3/` |
| 3.1 | Cross-platform hardening | `LAB-3.1.md` | `checkpoints/section-3.1/` |
| 3.2 | Ansible Vault | `LAB-3.2.md` | `checkpoints/section-3.2/` |
| 3.3 | Rolling deployment | `LAB-3.3.md` | `checkpoints/section-3.3/` |
| 4.1 | Testing & debugging | `LAB-4.1.md` | (uses `playbooks/broken/`) |
| 4.3 | Capstone — full project | `LAB-4.3.md` | `checkpoints/section-4.3/` |

## How the checkpoints are structured

Each `checkpoints/section-X.Y/` directory contains a complete, runnable copy of the workshop code as it should look at the end of that section. So `checkpoints/section-2.2/` includes the inventory, the playbooks from sections 1.4 / 2.1 / 2.2, the role you just refactored, and `ansible.cfg` — everything needed to run the section 2.2 playbook successfully.

If you fall behind during section 2.2 and want to catch up before section 2.3 starts:

```bash
cd checkpoints/section-2.2
ansible-playbook playbooks/03-web-tier-with-roles.yml
# Verify it works, then either continue from here or copy the files
# back to the workshop root and continue from there.
```

The final checkpoint, `checkpoints/section-4.3/`, is the **complete project** as it should exist at the end of the workshop. That's the artifact you take home.

## Expected output captures

Each lab guide references files in `docs/captures/` that contain real terminal output from a successful run of that section's playbooks. These were captured during the lab build pass by the workshop instructors. If your output looks meaningfully different from the captured version, that's a signal something went wrong.

If you're an instructor preparing to run this workshop, see `docs/captures/HOW-TO-CAPTURE.md` for the protocol on how to generate these captures during your build pass.

## Pre-workshop setup

Before the workshop starts, you should have:

- Received your **attendee card** at the door with your control node IP, SSH password, Windows admin password, Vault password, and the workshop repo URL
- A laptop with an SSH client (built-in on macOS/Linux/Windows 10+)

That's it. Everything else is in the lab.
