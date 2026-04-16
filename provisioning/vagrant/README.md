# Vagrant Provisioning — Local Fallback Path

> **This is the local fallback path.** Use it when you want to recreate the workshop lab on your own laptop, after the workshop is over (or if you're following along from home and don't have an Azure subscription).

## What this builds

The same lab as the Azure paths, but on your local machine using Vagrant + VirtualBox:

- `control` — Ubuntu 22.04 LTS, 2 vCPU / 2 GB RAM
- `web1` — Ubuntu 22.04 LTS, 1 vCPU / 1 GB RAM
- `mgmt1` — Windows Server 2022 Eval, 2 vCPU / 4 GB RAM

Total: ~5 vCPU and ~7 GB RAM at peak. The Windows Eval box is large (~5-8 GB to download on first run).

## Prerequisites

- **VirtualBox 7.x** — https://www.virtualbox.org/wiki/Downloads
- **Vagrant 2.4+** — https://www.vagrantup.com/downloads
- **30 GB free disk space** (the Windows VM disk + the Vagrant box file)
- **16 GB host RAM recommended**, 8 GB minimum
- **Hardware virtualization enabled in BIOS** (Intel VT-x or AMD-V) — most modern laptops have this on by default; corporate-managed laptops sometimes have it locked off

### Hyper-V conflict (Windows hosts only)

If you're running this on a Windows host machine, **VirtualBox and Hyper-V can't both be enabled** at the same time on older systems. If `vagrant up` fails with a virtualization error, try one of:

```powershell
# Disable Hyper-V (requires reboot)
bcdedit /set hypervisorlaunchtype off

# Re-enable later when you want Hyper-V back
bcdedit /set hypervisorlaunchtype auto
```

On Windows 10+ with WSL2, this gets more complicated. The simplest answer is "use Vagrant on a Linux or macOS host if you can, or use the Azure path."

## Usage

```bash
cd provisioning/vagrant

# First run: downloads the box files (this takes a while — ~10 GB)
vagrant up

# After first run:
vagrant up        # bring up VMs that are halted
vagrant halt      # gracefully shut down VMs
vagrant destroy   # delete VMs (preserves box files for next time)
vagrant ssh control   # SSH to the control node
```

After `vagrant up` succeeds, the lab is reachable from the control node:

```bash
vagrant ssh control
cd ~/workshop
ansible-playbook preflight/check.yml
```

## How this differs from the Azure paths

| Aspect | Azure | Vagrant |
|---|---|---|
| Cost | ~$1/hr per attendee | Free (uses your laptop) |
| Setup time | 10-15 min per attendee (parallelizable) | ~30 min for first run, ~3 min after |
| Network | Real subnets, real public IP | VirtualBox internal network |
| Windows VM image | Marketplace (always fresh) | Microsoft Eval ISO via Vagrant box |
| Performance | Cloud-class | Whatever your laptop can spare |
| Workshop day suitability | YES (primary path) | NO (too risky for 20+ attendees) |

## The `Vagrantfile`

The Vagrantfile defines the three VMs declaratively. Read it top to bottom — it's deliberately minimal so you can see what's happening. The control node runs the same cloud-init equivalent as the Azure path (just translated to a shell provisioner because Vagrant doesn't natively run cloud-init for non-cloud boxes).

The Windows VM uses the `gusztavvargadr/windows-server` Vagrant box, which is a community-maintained Windows Server 2022 Eval image. It's the most reliable Windows + Vagrant box currently available. License: 180-day Microsoft Eval, suitable for testing and learning.

## Troubleshooting

### "vagrant up hangs forever on the Windows VM"

The Windows box can take 10-15 minutes on first boot while Sysprep, cloud-init equivalents, and WinRM bootstrap all run. Be patient. If it's still hung after 20 minutes, check VirtualBox GUI to see what's on the Windows console — usually it's stuck waiting for Sysprep to finish.

### "The Windows box won't download"

Vagrant Cloud occasionally rate-limits box downloads. Try:

```bash
vagrant box add gusztavvargadr/windows-server --provider=virtualbox
```

If that fails, the box is mirrored on multiple CDNs — wait a few minutes and try again.

### "WinRM never comes up on mgmt1"

The Vagrantfile applies `winrm-bootstrap.ps1` (the same script used by the Azure path) via a shell provisioner. If WinRM isn't reachable from the control node after `vagrant up` finishes, RDP into mgmt1 manually (`vagrant rdp mgmt1` if you have an RDP client) and run the script by hand to see what's failing.

### "I get out-of-memory errors"

Drop the memory allocations in the Vagrantfile. The minimums that still work:
- control: 1 GB
- web1: 512 MB
- mgmt1: 3 GB (can't go lower for Windows Server)

That's 4.5 GB total — should fit on an 8 GB host with everything else closed.

## What's NOT in the Vagrant path

- **No per-attendee multiplication.** This is a single lab on your laptop, not a fleet.
- **No public IPs or NSGs.** Everything is on a VirtualBox internal network.
- **No credentials CSV.** You're the only "attendee" — the credentials are hardcoded in the Vagrantfile (default `vagrant`/`vagrant` for the Linux boxes, `vagrant`/`Passw0rd!` for Windows).
- **No teardown script.** Just `vagrant destroy` when you're done.
