# Building End-to-End Automation with Ansible

**A Hands-On Workshop for Solving Real-World Problems**

A 4-hour, dual-instructor workshop on using Ansible to automate a hybrid Linux + Windows environment. Built around the "new branch office standup" scenario, this workshop teaches Ansible fundamentals through PowerShell + Windows integration, security hardening, secrets management with Vault, and rolling deployment patterns.

> **Audience:** IT pros from help desk through sysadmin, with stronger Windows administration backgrounds. Linux familiarity is helpful but not required. No Ansible or PowerShell expertise expected.
>
> **Format:** 4 hours, hands-on, two instructors. Roughly 40% instruction / 60% lab time.

## The Scenario

You've been handed the "new branch office build" project. Every branch your company opens needs the same baseline:

- A Linux web server hosting the branch's internal status page and intranet tooling
- A Windows management host for local file shares, package management, and as the IT team's jump box
- All of it hardened to corporate security standards
- All of it repeatable, because you'll be doing this again next quarter

By the end of the workshop, you'll have a complete, working Ansible project that does all of this with one command — and a reusable framework you can take back to your own environment.

## Lab Topology

```
                    ┌─────────────────────────┐
                    │   Attendee laptop       │
                    │   (any OS, just SSH)    │
                    └──────────┬──────────────┘
                               │ SSH (port 22)
                               │ + port forwards for RDP/HTTP
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Azure resource group (one per attendee)                     │
│                                                              │
│   ┌──────────────────┐                                       │
│   │   control        │  ◄── only host with a public IP      │
│   │   Ubuntu 22.04   │      Ansible installed here          │
│   │   Public IP      │      pywinrm pre-installed           │
│   └──────┬───────────┘                                       │
│          │                                                   │
│          │  private vnet (10.0.0.0/16)                       │
│          │                                                   │
│   ┌──────┴───────────┐      ┌──────────────────┐             │
│   │   web1           │      │   mgmt1          │             │
│   │   Ubuntu 22.04   │      │   Win Server 2022│             │
│   │   Private IP     │      │   Private IP     │             │
│   │   nginx          │      │   WinRM (5986)   │             │
│   └──────────────────┘      └──────────────────┘             │
│                                                              │
│   (web2 added during section 3.3 for rolling deploy demo)    │
└──────────────────────────────────────────────────────────────┘
```

**Why the jump-box pattern?** Only the `control` node has a public IP. Web and Windows hosts are reachable only through `control`, which is exactly how a real branch office would be set up. This also means you only need outbound SSH (port 22) from your laptop — no RDP, no special firewall holes. To access the Windows host's RDP or the web server's HTTP, you forward ports through SSH from the control node. Instructions are in `LAB-1.4.md`.

## Workshop Sections

> **The 4-hour clock starts at section 1.1.** All Azure provisioning happens before workshop day — attendees walk in to a fully-built lab and start by SSHing into a pre-provisioned control node.

| Section | Topic | Time | Lab file |
|---|---|---|---|
| 1.1 | Welcome, scenario, finished-product demo | 10 min | — |
| 1.2 | Lab topology walkthrough (Azure portal) | 10 min | — |
| 1.3 | Ansible fundamentals speed run | 20 min | — |
| 1.4 | **Hands-on lab access** — first time attendees touch the lab | 20 min | `LAB-1.4.md` |
| 2.1 | Writing your first real playbook | 15 min | `LAB-2.1.md` |
| 2.2 | Structuring with roles | 15 min | `LAB-2.2.md` |
| 2.3 | PowerShell + Windows automation | 20 min | `LAB-2.3.md` |
| 2.4 | **Lab checkpoint #2** — multi-platform run | 10 min | (in 2.3) |
| 3.1 | Security hardening as code | 20 min | `LAB-3.1.md` |
| 3.2 | Ansible Vault & secrets | 15 min | `LAB-3.2.md` |
| 3.3 | Orchestration & rolling deploys | 15 min | `LAB-3.3.md` |
| 3.4 | **Lab checkpoint #3** — full stack run | 10 min | (in 3.3) |
| 4.1 | Testing & debugging | 15 min | `LAB-4.1.md` |
| 4.2 | Scaling & maintainability | 15 min | — |
| 4.3 | **Capstone** — complete the project | 20 min | `LAB-4.3.md` |
| 4.4 | Wrap-up & resources | 10 min | — |

See `LAB-OVERVIEW.md` for the full lab guide index.

## Quick Start (Workshop Day — Attendees)

When you arrive, your instructor will hand you an **attendee card** at the door. The card has:

- Your attendee number
- The public IP of your `control` node
- Your SSH username and password
- The workshop Vault password (also posted on a slide during section 3.2)
- The URL of this repo (so you can browse the code during and after the workshop)

You don't need anything else. **No Azure account, no local tools beyond an SSH client.** A Mac, Linux laptop, or Windows 10+ machine with built-in `ssh.exe` will work — even a Chromebook with an SSH app is fine.

In section 1.4, your instructor will walk you through your first hands-on time with the lab:

```bash
# SSH into your control node (replace with the IP from your card)
ssh attendee@<your-control-ip>

# The workshop repo is already cloned at ~/workshop
cd ~/workshop

# Run the preflight playbook to confirm the lab is ready
ansible-playbook preflight/check.yml
```

Then you'll set up SSH port forwards to reach the web server and the Windows host through your control node, and confirm you can RDP. By the end of section 1.4, you'll be ready for the rest of the workshop.

**You will NOT need to provision anything in Azure.** All of that is handled by your instructor before the workshop starts. The provisioning code is in this repo so you can reproduce the lab on your own time after the workshop — see "Reproducing this lab on your own" below.

## Reproducing This Lab On Your Own (Post-Workshop)

After the workshop, you can recreate the entire lab environment yourself in three different ways:

| Option | Best for | Path |
|---|---|---|
| **Vagrant + VirtualBox** | Running locally on your laptop, no cloud account required | `provisioning/vagrant/` |
| **Azure (Ansible)** | Running in Azure with full instructor automation | `provisioning/azure/` |
| **Azure (Bicep)** | Running in Azure if you prefer Microsoft-native tooling | `provisioning/bicep/` |

The Vagrant path is the most accessible — it builds the same three-VM lab on your own machine using free tools, with no Azure subscription needed. See `provisioning/vagrant/README.md` for prerequisites and the `vagrant up` workflow.

The Azure paths reproduce the exact workshop infrastructure (per-attendee resource groups, jump-box pattern, WinRM bootstrap on the Windows VM) and are appropriate if you want to run this workshop yourself for your own team. See `provisioning/README.md` for a full comparison of the three paths.

> **Workshop attendees: you do not need any of this on workshop day.** It's reference material for after the workshop, or for instructors who want to run the workshop themselves.

## Repository Structure

```
.
├── README.md                       # You are here
├── INSTRUCTOR-SETUP.md             # Everything Joe does BEFORE workshop day
├── LAB-OVERVIEW.md                 # Index of all lab guides
├── LAB-1.4.md ... LAB-4.3.md      # Per-section hands-on lab guides
├── ansible.cfg                     # Workshop's Ansible configuration
├── requirements.yml                # Pinned Galaxy collections
├── .vault-pass.example             # Placeholder — copy to .vault-pass
│
├── provisioning/                   # How the lab gets built (instructor only)
│   ├── azure/                      # Primary: Ansible-driven Azure provisioning
│   │   └── generate-attendee-cards.ps1   # PowerShell card generator
│   ├── bicep/                      # Backup: same lab in Bicep
│   └── vagrant/                    # Local fallback: Vagrant for homelab use
│
├── preflight/
│   └── check.yml                   # The "you just ran Ansible" ceremony
│
├── inventory/
│   ├── hosts.yml                   # web1, web2, mgmt1
│   └── group_vars/
│       ├── all.yml                 # Branch metadata
│       ├── linux.yml               # SSH + Python interpreter
│       └── windows/                # WinRM connection + Vault indirection
│           ├── vars.yml
│           └── vault.yml.example
│
├── playbooks/
│   ├── 01-hello-world.yml          # Section 2.1 — trivial first playbook
│   ├── 02-web-tier.yml             # Section 2.1 — monolithic web tier
│   ├── 03-web-tier-with-roles.yml  # Section 2.2 — role-based web tier
│   ├── 04-windows-mgmt.yml         # Section 2.3 — Windows management host
│   ├── 05-harden.yml               # Section 3.1 — cross-platform hardening
│   ├── 06-rolling-deploy.yml       # Section 3.3 — rolling deployment
│   ├── site.yml                    # Section 4.3 — capstone, builds everything
│   └── broken/
│       └── broken-web-deploy.yml   # Section 4.1 — intentionally broken
│
├── roles/
│   ├── webserver/                  # Built in section 2.2
│   ├── windows-mgmt/              # Built in section 2.3
│   └── hardening/                  # Built in section 3.1
│
├── templates/
│   ├── status.html.j2             # Branch office status page
│   └── nginx-site.conf.j2         # nginx site config
│
├── checkpoints/                    # Per-section recovery snapshots
│   ├── section-1.4/ ... section-4.3/
│   └── section-4.3/               # Final complete state
│
├── docs/
│   ├── runbook.md                  # Day-of runbook (both instructors)
│   └── captures/                   # Real terminal output from the build pass
│       ├── HOW-TO-CAPTURE.md
│       └── capture.sh
│
└── slides/
    ├── template.pptx               # Conference template (do not edit)
    ├── build-slides.py             # Generates workshop.pptx from template
    ├── workshop.pptx               # The deck (regenerate with build-slides.py)
    └── speaker-notes.md            # Per-slide lectern reference
```

## For Workshop Instructors

If you're running this workshop yourself:

1. Start with `INSTRUCTOR-SETUP.md` at the repo root — it's the complete pre-workshop checklist (Azure quotas, provisioning, card generation, the capture pass).
2. On workshop day, use `docs/runbook.md` — it's the minute-by-minute pacing guide with dual-instructor coordination and contingency procedures.
3. Before workshop day, run the output capture pass described in `docs/captures/HOW-TO-CAPTURE.md` to generate the real terminal output that lab guides reference.

## Credits

This workshop was originally presented at **[PowerShell & DevOps Summit 2026](https://www.powershellsummit.org)** by Joe Houghes and Mike Nelson.

- **Ansible reference patterns:** Adapted (with thanks) from [`geerlingguy/ansible-for-devops`](https://github.com/geerlingguy/ansible-for-devops), MIT-licensed.
- **Windows + Ansible reference material:** Jordan Borean (Ansible Core team Windows specialist), Josh King ("Ansible 101 for the Windows SysAdmin"), Paul Broadwith, Jeremy Murrah.
- **Workshop structure & pedagogy:** Drawn from the canon: *Ansible: Up and Running* (3rd ed.), *Ansible for DevOps* (Geerling), and the Learn Linux TV "Getting Started with Ansible" video series.

See `slides/workshop.pptx` (final slides) for the full attribution and reading list.

## License

MIT — see `LICENSE`. You're free to fork this repo, adapt it for your own workshops, and use it as the foundation for your own automation projects. Credit appreciated but not required.
