#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates printable attendee cards from the credentials CSV.

.DESCRIPTION
    Reads provisioning/azure/attendee-credentials.csv and produces an HTML
    file with one attendee card per page, designed to be printed on cardstock
    and folded into a tent or laid flat.

    Each card contains:
      - Attendee number (large)
      - Control node public IP
      - SSH username and password
      - Workshop Vault password
      - Workshop repo URL (written out, no QR code — QR is on slides)

.PARAMETER CsvPath
    Path to the credentials CSV. Defaults to ./attendee-credentials.csv

.PARAMETER OutputPath
    Path where the HTML file is written. Defaults to ./attendee-cards.html

.PARAMETER RepoUrl
    The workshop repo URL printed on each card. Defaults to the public repo URL.

.EXAMPLE
    pwsh ./generate-attendee-cards.ps1
    Generates attendee-cards.html from attendee-credentials.csv in the current directory.

.EXAMPLE
    pwsh ./generate-attendee-cards.ps1 -CsvPath ./test-creds.csv -OutputPath ./test-cards.html
    Custom paths.

.NOTES
    To print: open attendee-cards.html in a browser, then File > Print.
    Set the printer to landscape (or portrait — both work, the cards are square-ish).
    Print on cardstock (recommended) for cards that hold up to handling.
    The CSS uses page-break-after to ensure one card per page.
#>

[CmdletBinding()]
param(
    [string]$CsvPath = "./attendee-credentials.csv",
    [string]$OutputPath = "./attendee-cards.html",
    [string]$RepoUrl = "https://github.com/jhoughes/ansible-branch-office-workshop-base"
)

# -----------------------------------------------------------------------------
# Validate inputs
# -----------------------------------------------------------------------------
if (-not (Test-Path $CsvPath)) {
    Write-Error "Credentials CSV not found at: $CsvPath"
    Write-Error "Run 'ansible-playbook site.yml' first to generate it."
    exit 1
}

# -----------------------------------------------------------------------------
# Read the CSV
# -----------------------------------------------------------------------------
Write-Host "==> Reading credentials from $CsvPath" -ForegroundColor Cyan
$attendees = Import-Csv -Path $CsvPath

if ($attendees.Count -eq 0) {
    Write-Error "Credentials CSV is empty. Did site.yml complete successfully?"
    exit 1
}

Write-Host "    Found $($attendees.Count) attendees"

# -----------------------------------------------------------------------------
# Build the HTML
# -----------------------------------------------------------------------------
# CSS: each .card is sized to fill a printed page. The @page rule sets letter
# size with reasonable margins. The page-break-after on .card ensures one card
# per page when printing.

$htmlHeader = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Workshop Attendee Cards</title>
<style>
    @page {
        size: letter;
        margin: 0.5in;
    }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        margin: 0;
        padding: 0;
    }
    .card {
        width: 7.5in;
        height: 10in;
        padding: 0.5in;
        box-sizing: border-box;
        page-break-after: always;
        border: 3px solid #1f4e79;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    }
    .card:last-child {
        page-break-after: auto;
    }
    .header {
        text-align: center;
        border-bottom: 2px solid #1f4e79;
        padding-bottom: 0.3in;
        margin-bottom: 0.3in;
    }
    .header h1 {
        margin: 0;
        font-size: 32pt;
        color: #1f4e79;
    }
    .header .subtitle {
        font-size: 14pt;
        color: #666;
        margin-top: 0.1in;
    }
    .attendee-number {
        font-size: 72pt;
        font-weight: bold;
        text-align: center;
        color: #1f4e79;
        margin: 0.2in 0;
    }
    .credentials {
        background: #f5f5f5;
        border-left: 6px solid #1f4e79;
        padding: 0.25in;
        margin: 0.2in 0;
    }
    .credential-row {
        display: flex;
        align-items: baseline;
        margin: 0.12in 0;
        font-size: 14pt;
    }
    .credential-label {
        font-weight: bold;
        min-width: 2.4in;
        color: #1f4e79;
    }
    .credential-value {
        font-family: "SF Mono", "Consolas", "Monaco", monospace;
        font-size: 16pt;
        background: white;
        padding: 0.05in 0.15in;
        border: 1px solid #ccc;
        border-radius: 3px;
        flex-grow: 1;
        word-break: break-all;
    }
    .vault {
        background: #fff8dc;
        border-left-color: #b8860b;
    }
    .vault .credential-label {
        color: #b8860b;
    }
    .footer {
        text-align: center;
        font-size: 11pt;
        color: #666;
        border-top: 1px solid #ccc;
        padding-top: 0.2in;
    }
    .repo-url {
        font-family: "SF Mono", "Consolas", "Monaco", monospace;
        font-size: 12pt;
        color: #1f4e79;
        margin-top: 0.1in;
        word-break: break-all;
    }
    .instructions {
        font-size: 11pt;
        color: #555;
        margin: 0.15in 0;
        padding: 0.15in;
        background: #eef5fb;
        border-radius: 4px;
    }
    .instructions strong {
        color: #1f4e79;
    }
</style>
</head>
<body>
'@

$htmlFooter = @'
</body>
</html>
'@

# -----------------------------------------------------------------------------
# Generate one card per attendee
# -----------------------------------------------------------------------------
$cards = foreach ($a in $attendees) {
    @"
<div class="card">
    <div class="header">
        <h1>Building End-to-End Automation with Ansible</h1>
        <div class="subtitle">PowerShell &amp; DevOps Summit 2026</div>
    </div>

    <div class="attendee-number">Attendee $($a.attendee_number)</div>

    <div class="instructions">
        <strong>Workshop day:</strong> SSH into your control node using the credentials below.
        Your instructor will walk you through the rest in section 1.4.
    </div>

    <div class="credentials">
        <div class="credential-row">
            <div class="credential-label">Control node IP:</div>
            <div class="credential-value">$($a.control_public_ip)</div>
        </div>
        <div class="credential-row">
            <div class="credential-label">SSH username:</div>
            <div class="credential-value">$($a.ssh_username)</div>
        </div>
        <div class="credential-row">
            <div class="credential-label">SSH password:</div>
            <div class="credential-value">$($a.ssh_password)</div>
        </div>
        <div class="credential-row">
            <div class="credential-label">Windows admin user:</div>
            <div class="credential-value">$($a.windows_admin_username)</div>
        </div>
        <div class="credential-row">
            <div class="credential-label">Windows admin password:</div>
            <div class="credential-value">$($a.windows_admin_password)</div>
        </div>
    </div>

    <div class="credentials vault">
        <div class="credential-row">
            <div class="credential-label">Workshop Vault password:</div>
            <div class="credential-value">$($a.vault_password)</div>
        </div>
        <div style="font-size: 10pt; color: #666; margin-top: 0.1in;">
            (Same Vault password for all attendees — also posted on a slide during section 3.2)
        </div>
    </div>

    <div class="footer">
        <div>Workshop repository:</div>
        <div class="repo-url">$RepoUrl</div>
    </div>
</div>
"@
}

# -----------------------------------------------------------------------------
# Write the file
# -----------------------------------------------------------------------------
$html = $htmlHeader + ($cards -join "`n") + $htmlFooter
Set-Content -Path $OutputPath -Value $html -Encoding UTF8

Write-Host ""
Write-Host "==> Generated $OutputPath" -ForegroundColor Green
Write-Host "    $($attendees.Count) cards, one per page"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open $OutputPath in a browser"
Write-Host "  2. File > Print (or Ctrl+P / Cmd+P)"
Write-Host "  3. Set destination to your printer (or 'Save as PDF')"
Write-Host "  4. Recommended: print on cardstock for durability"
Write-Host "  5. Cut along page boundaries — each page is one card"
Write-Host ""
Write-Host "Treat the printed cards as SECRETS until they're handed out." -ForegroundColor Yellow
