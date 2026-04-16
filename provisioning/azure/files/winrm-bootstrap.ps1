# =============================================================================
# winrm-bootstrap.ps1
# =============================================================================
# Configures the Windows Server 2022 VM for Ansible WinRM access.
#
# This script is fetched by the Azure Custom Script Extension on first boot
# and runs as SYSTEM. By the time it finishes, the workshop's control node
# can connect to this VM via Ansible's winrm connection plugin.
#
# What it does:
#   1. Enables WinRM with HTTPS on port 5986
#   2. Generates a self-signed certificate (lab use only — production should
#      use a proper CA-signed cert)
#   3. Creates the WinRM HTTPS listener bound to that certificate
#   4. Opens the firewall for inbound TCP 5986 from the lab subnet only
#   5. Sets the LocalAccountTokenFilterPolicy to allow remote admin
#   6. Writes a marker file the verify.yml playbook can check
#
# Why a script and not the official Ansible-provided ConfigureRemotingForAnsible.ps1?
#   - The official script is great but does more than we need (HTTP listener,
#     basic auth, broader firewall rules). For a lab where the only client is
#     a known control node on a known subnet, we want a tighter footprint.
#   - This script is also easier to read for a Windows admin who's never seen
#     WinRM bootstrapped before, and the workshop audience is exactly that.
#
# Adapted from patterns in the canonical ConfigureRemotingForAnsible.ps1 and
# Ansible documentation, then trimmed for lab use.
# =============================================================================

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # speeds up everything that uses Write-Progress

Write-Host "==> Workshop WinRM bootstrap starting at $(Get-Date)" -ForegroundColor Green

# -----------------------------------------------------------------------------
# Step 1: Make sure WinRM service is running
# -----------------------------------------------------------------------------
Write-Host "==> Ensuring WinRM service is running..." -ForegroundColor Cyan
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM
Write-Host "    WinRM service: $((Get-Service -Name WinRM).Status)"

# -----------------------------------------------------------------------------
# Step 2: Enable PowerShell Remoting
# -----------------------------------------------------------------------------
# Enable-PSRemoting also configures WinRM, sets up listeners, and opens
# firewall rules. We override its defaults below to be tighter.
Write-Host "==> Enabling PowerShell Remoting..." -ForegroundColor Cyan
Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null

# -----------------------------------------------------------------------------
# Step 3: Generate a self-signed certificate for HTTPS
# -----------------------------------------------------------------------------
# In production you'd use a CA-signed cert. For the lab, self-signed is fine
# because the workshop's control node is configured to skip cert validation
# (ansible_winrm_server_cert_validation: ignore).
Write-Host "==> Generating self-signed certificate for WinRM HTTPS..." -ForegroundColor Cyan

$hostname = $env:COMPUTERNAME
$cert = New-SelfSignedCertificate `
    -DnsName $hostname, "$hostname.local", "mgmt1" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -KeyUsage DigitalSignature, KeyEncipherment `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddYears(1)

Write-Host "    Cert thumbprint: $($cert.Thumbprint)"

# -----------------------------------------------------------------------------
# Step 4: Remove any existing HTTP listener (we only want HTTPS)
# -----------------------------------------------------------------------------
Write-Host "==> Removing default HTTP listener (we only want HTTPS)..." -ForegroundColor Cyan
Get-ChildItem -Path WSMan:\localhost\Listener |
    Where-Object { $_.Keys -contains "Transport=HTTP" } |
    ForEach-Object {
        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
    }

# -----------------------------------------------------------------------------
# Step 5: Create the HTTPS listener
# -----------------------------------------------------------------------------
Write-Host "==> Creating WinRM HTTPS listener on port 5986..." -ForegroundColor Cyan

# Remove any existing HTTPS listener so we start clean
Get-ChildItem -Path WSMan:\localhost\Listener |
    Where-Object { $_.Keys -contains "Transport=HTTPS" } |
    ForEach-Object {
        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
    }

New-Item -Path WSMan:\localhost\Listener `
    -Address * `
    -Transport HTTPS `
    -Hostname $hostname `
    -CertificateThumbPrint $cert.Thumbprint `
    -Port 5986 `
    -Force | Out-Null

# -----------------------------------------------------------------------------
# Step 6: WinRM service settings — allow basic auth, allow unencrypted off
# -----------------------------------------------------------------------------
# Note: "AllowUnencrypted = false" is the secure default. We're enabling Basic
# auth because the workshop uses username/password (not Kerberos). Basic auth
# is fine ONLY because we're going over HTTPS.
Write-Host "==> Configuring WinRM service settings..." -ForegroundColor Cyan

Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false

# Bump up the limits a bit so the workshop's larger playbooks don't hit them
Set-Item -Path WSMan:\localhost\Service\MaxConcurrentOperationsPerUser -Value 4294967295
Set-Item -Path WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 1024

# -----------------------------------------------------------------------------
# Step 7: Firewall — allow inbound 5986 from the lab subnet only
# -----------------------------------------------------------------------------
# We deliberately scope this to the local subnet (10.x.0.0/16). The control
# node is in the same vnet, so it can reach this. Anything outside the vnet
# can't, even if the Azure NSG were misconfigured. Defense in depth.
Write-Host "==> Configuring Windows Firewall for WinRM HTTPS (lab subnet only)..." -ForegroundColor Cyan

# Remove any pre-existing rules with the same name so re-runs are idempotent
Get-NetFirewallRule -DisplayName "Workshop WinRM HTTPS" -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

New-NetFirewallRule `
    -DisplayName "Workshop WinRM HTTPS" `
    -Description "Allow Ansible WinRM from the workshop lab subnet" `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 5986 `
    -RemoteAddress "10.0.0.0/8" `
    -Profile Any `
    -Enabled True | Out-Null

# Also allow ICMP from the lab subnet so the control node can ping us
# (ansible -m win_ping doesn't actually use ICMP, but a regular ping is
# helpful for troubleshooting)
Get-NetFirewallRule -DisplayName "Workshop ICMP" -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

New-NetFirewallRule `
    -DisplayName "Workshop ICMP" `
    -Direction Inbound `
    -Action Allow `
    -Protocol ICMPv4 `
    -RemoteAddress "10.0.0.0/8" `
    -Profile Any `
    -Enabled True | Out-Null

# -----------------------------------------------------------------------------
# Step 8: LocalAccountTokenFilterPolicy
# -----------------------------------------------------------------------------
# Without this, local administrators connecting remotely get a filtered token
# (i.e., they're effectively standard users). The workshop's local admin
# account needs full admin rights to manage the box, so we set this to 1.
Write-Host "==> Setting LocalAccountTokenFilterPolicy..." -ForegroundColor Cyan

New-ItemProperty `
    -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "LocalAccountTokenFilterPolicy" `
    -Value 1 `
    -PropertyType DWord `
    -Force | Out-Null

# -----------------------------------------------------------------------------
# Step 9: Restart WinRM to pick up all changes
# -----------------------------------------------------------------------------
Write-Host "==> Restarting WinRM service to apply changes..." -ForegroundColor Cyan
Restart-Service -Name WinRM -Force
Start-Sleep -Seconds 2

# -----------------------------------------------------------------------------
# Step 10: Smoke test — can we talk to ourselves over the new HTTPS listener?
# -----------------------------------------------------------------------------
Write-Host "==> Smoke testing the new HTTPS listener..." -ForegroundColor Cyan

try {
    $listeners = Get-ChildItem -Path WSMan:\localhost\Listener
    $httpsListener = $listeners | Where-Object { $_.Keys -contains "Transport=HTTPS" }

    if ($httpsListener) {
        Write-Host "    HTTPS listener is configured:" -ForegroundColor Green
        Get-ChildItem -Path "WSMan:\localhost\Listener\$($httpsListener.Name)" |
            ForEach-Object { Write-Host "      $($_.Name) = $($_.Value)" }
    } else {
        throw "No HTTPS listener found after configuration!"
    }
} catch {
    Write-Host "    SMOKE TEST FAILED: $_" -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------------
# Step 11: Marker file for the verify.yml playbook
# -----------------------------------------------------------------------------
$markerPath = "C:\workshop-winrm-bootstrap-complete.txt"
Set-Content -Path $markerPath -Value @"
WinRM bootstrap completed successfully.
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Hostname: $hostname
Cert thumbprint: $($cert.Thumbprint)
HTTPS listener: port 5986
Firewall: allowing TCP 5986 from 10.0.0.0/8

The verify.yml playbook checks for the existence of this file as proof
that the bootstrap script ran to completion. If you're reading this on
the VM and Ansible still can't connect, check:
  - Get-NetFirewallRule -DisplayName "Workshop WinRM HTTPS"
  - Get-ChildItem WSMan:\localhost\Listener
  - Test-NetConnection -ComputerName <control-node-ip> -Port 22
"@

Write-Host ""
Write-Host "==> Workshop WinRM bootstrap complete at $(Get-Date)" -ForegroundColor Green
Write-Host "    Marker file: $markerPath"
exit 0
