# =============================================================================
# inventory-report.ps1
# =============================================================================
# A custom PowerShell script that gathers a small inventory report about
# the Windows host it runs on. Called by the windows-mgmt role via the
# ansible.windows.win_powershell module.
#
# Why this exists in the workshop:
#   This is the "you can write your own PowerShell, run it via Ansible, and
#   capture the result as a registered variable" demonstration. The audience
#   already speaks PowerShell — this script shows them they don't have to
#   abandon what they know to use Ansible. They write PowerShell, Ansible
#   orchestrates it.
#
# The script returns a hashtable. ansible.windows.win_powershell captures
# the last expression in the script as the .output property of the
# registered variable. So after this script runs:
#
#   inventory_report.output.Hostname        → "mgmt1"
#   inventory_report.output.OSVersion       → "Microsoft Windows Server 2022 Standard"
#   inventory_report.output.MemoryGB        → 8.0
#   ...etc
#
# The lab guide in LAB-2.3.md walks attendees through extending this
# script with their own additions.
# =============================================================================

# Get computer info — modern PowerShell way that returns rich data
$computerInfo = Get-ComputerInfo -Property `
    CsName, OsName, OsVersion, OsTotalVisibleMemorySize, CsNumberOfLogicalProcessors

# Calculate uptime
$uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$uptimeHours = [math]::Round($uptime.TotalHours, 1)

# Count installed apps (uses the registry, much faster than Get-Package)
$installedAppCount = @(
    Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
    Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
).Where({ $_.DisplayName }).Count

# Count local user accounts (excluding built-ins)
$localUserCount = (Get-LocalUser).Count

# Count SMB shares (excluding the built-in admin shares like C$, IPC$, ADMIN$)
$shareCount = (Get-SmbShare | Where-Object { $_.Name -notmatch '\$$' }).Count

# Return a hashtable. ansible.windows.win_powershell will capture this as
# the .output property of the registered variable, with each key accessible
# via dotted notation (e.g., inventory_report.output.Hostname).
@{
    Hostname          = $computerInfo.CsName
    OSVersion         = $computerInfo.OsName
    MemoryGB          = [math]::Round($computerInfo.OsTotalVisibleMemorySize / 1MB, 1)
    CPUCores          = $computerInfo.CsNumberOfLogicalProcessors
    UptimeHours       = $uptimeHours
    InstalledAppCount = $installedAppCount
    LocalUserCount    = $localUserCount
    ShareCount        = $shareCount
    GeneratedAt       = (Get-Date).ToString('o')
}
