#!/usr/bin/env bash
#
# deploy-all.sh — Provision all attendee labs using Bicep
#
# This is the Bicep equivalent of `ansible-playbook site.yml`. It loops over
# the configured attendee count, generates per-attendee credentials, deploys
# the main.bicep template into a per-attendee resource group, and writes the
# credentials CSV at the end.
#
# Run from this directory: provisioning/bicep/
#
# Usage:
#     ./deploy-all.sh
#     ./deploy-all.sh --count 5             # provision only 5 attendees
#     ./deploy-all.sh --start 21 --count 5  # provision attendees 21-25
#     ./deploy-all.sh --instructor          # provision the instructor (att 99)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Defaults — edit these for your workshop
# -----------------------------------------------------------------------------
ATTENDEE_COUNT=20
START_FROM=1
LOCATION="westus2"
WORKSHOP_NAME="workshop"
WORKSHOP_DATE="2026-12-31"
ALLOWED_SSH_SOURCES='["0.0.0.0/0"]'  # CHANGE before workshop day
WORKSHOP_VAULT_PASSWORD="POWERSHELL&DEVOPS_SUMMIT_2026!"
# Replace this with your own commit-pinned GitHub Gist raw URL.
# See provisioning/azure/roles/attendee-rg/defaults/main.yml for the format.
WINRM_SCRIPT_URL="https://gist.githubusercontent.com/REPLACE_WITH_YOUR_GIST_USERNAME/REPLACE_WITH_GIST_ID/raw/REPLACE_WITH_COMMIT_SHA/winrm-bootstrap.ps1"
CLOUD_INIT_FILE="../azure/roles/attendee-rg/templates/cloud-init-control.yml.j2"

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
INSTRUCTOR_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --count)
            ATTENDEE_COUNT="$2"
            shift 2
            ;;
        --start)
            START_FROM="$2"
            shift 2
            ;;
        --instructor)
            INSTRUCTOR_ONLY=true
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Pre-flight
# -----------------------------------------------------------------------------
echo "==> Pre-flight checks..."

if ! command -v az >/dev/null 2>&1; then
    echo "ERROR: Azure CLI (az) not found in PATH" >&2
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo "ERROR: Not logged into Azure. Run: az login" >&2
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "    Subscription: ${SUBSCRIPTION} (${SUBSCRIPTION_ID})"
echo ""
echo "    Press Ctrl-C now if that's the wrong subscription. Continuing in 5 seconds..."
sleep 5

# -----------------------------------------------------------------------------
# Render the cloud-init file (the .j2 has Jinja syntax we need to fill in)
# -----------------------------------------------------------------------------
# Bicep can't render Jinja, so we do a simple sed substitution. The cloud-init
# file uses just a few variables, all of which we know at this point.
echo ""
echo "==> Rendering cloud-init file..."

CLOUD_INIT_RENDERED=$(mktemp)
trap 'rm -f "${CLOUD_INIT_RENDERED}"' EXIT

sed \
    -e "s|{{ attendee_ssh_username }}|attendee|g" \
    -e "s|{{ workshop_repo_branch }}|main|g" \
    -e "s|{{ workshop_repo_url }}|https://github.com/jhoughes/ansible-branch-office-workshop-base.git|g" \
    "${CLOUD_INIT_FILE}" > "${CLOUD_INIT_RENDERED}"

CLOUD_INIT_BASE64=$(base64 -w 0 "${CLOUD_INIT_RENDERED}")
echo "    Cloud-init rendered, $(wc -c < "${CLOUD_INIT_RENDERED}") bytes"

# -----------------------------------------------------------------------------
# Decide which attendees to provision
# -----------------------------------------------------------------------------
if [[ "${INSTRUCTOR_ONLY}" == "true" ]]; then
    ATTENDEES=(99)
    echo ""
    echo "==> Provisioning instructor lab only (attendee 99)"
else
    ATTENDEES=()
    for ((i=START_FROM; i<START_FROM+ATTENDEE_COUNT; i++)); do
        ATTENDEES+=("${i}")
    done
    echo ""
    echo "==> Provisioning ${#ATTENDEES[@]} attendees: ${ATTENDEES[*]}"
fi

# -----------------------------------------------------------------------------
# Generate a random password (alphanumeric, no shell-special chars)
# -----------------------------------------------------------------------------
generate_password() {
    local length="${1:-16}"
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${length}"
}

# -----------------------------------------------------------------------------
# Initialize the credentials CSV
# -----------------------------------------------------------------------------
CSV_FILE="attendee-credentials.csv"
echo "attendee_number,attendee_name,control_public_ip,ssh_username,ssh_password,windows_admin_username,windows_admin_password,vault_password" > "${CSV_FILE}"
chmod 600 "${CSV_FILE}"

# -----------------------------------------------------------------------------
# Loop over attendees
# -----------------------------------------------------------------------------
for n in "${ATTENDEES[@]}"; do
    # Pad with leading zero
    NUM=$(printf "%02d" "${n}")
    RG="${WORKSHOP_NAME}-att-${NUM}-rg"

    echo ""
    echo "==> [Attendee ${NUM}] Generating passwords..."
    SSH_PASSWORD=$(generate_password 16)
    WIN_PASSWORD="$(generate_password 18)Aa1!"  # ensure Windows complexity

    echo "==> [Attendee ${NUM}] Creating resource group ${RG}..."
    az group create \
        --name "${RG}" \
        --location "${LOCATION}" \
        --tags "workshop=branch-office-ansible" "attendee=${NUM}" "managed_by=bicep" "delete_after=${WORKSHOP_DATE}" \
        --output none

    echo "==> [Attendee ${NUM}] Deploying main.bicep..."
    DEPLOYMENT_OUTPUT=$(az deployment group create \
        --resource-group "${RG}" \
        --template-file main.bicep \
        --parameters \
            attendeeNumber="${NUM}" \
            location="${LOCATION}" \
            workshopName="${WORKSHOP_NAME}" \
            sshUsername="attendee" \
            sshPassword="${SSH_PASSWORD}" \
            windowsAdminUsername="workshop_admin" \
            windowsAdminPassword="${WIN_PASSWORD}" \
            allowedSshSources="${ALLOWED_SSH_SOURCES}" \
            winrmBootstrapScriptUrl="${WINRM_SCRIPT_URL}" \
            cloudInitBase64="${CLOUD_INIT_BASE64}" \
            workshopDate="${WORKSHOP_DATE}" \
        --query properties.outputs \
        --output json)

    CONTROL_IP=$(echo "${DEPLOYMENT_OUTPUT}" | jq -r '.controlPublicIp.value')

    echo "==> [Attendee ${NUM}] Done. Control IP: ${CONTROL_IP}"

    # Append to credentials CSV
    echo "${NUM},attendee${NUM},${CONTROL_IP},attendee,${SSH_PASSWORD},workshop_admin,${WIN_PASSWORD},${WORKSHOP_VAULT_PASSWORD}" >> "${CSV_FILE}"
done

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "Provisioning complete."
echo ""
echo "  Credentials file: $(pwd)/${CSV_FILE}"
echo "  Permissions:      0600 (owner read/write only)"
echo ""
echo "  Treat this file as a SECRET. It contains every attendee's"
echo "  SSH password and the workshop Vault password."
echo ""
echo "  Next steps:"
echo "    1. Print the credentials onto attendee cards"
echo "    2. Run ./verify.sh to confirm SSH + WinRM are reachable"
echo "    3. After the workshop, run ./teardown.sh"
echo "============================================================"
