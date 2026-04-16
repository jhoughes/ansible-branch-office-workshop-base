#!/usr/bin/env bash
#
# verify.sh — Day-before sanity check for the Bicep provisioning path
#
# Bash equivalent of `ansible-playbook verify.yml`. Iterates over the
# attendee-credentials.csv file and confirms each control node is reachable.
#
# Usage:
#     ./verify.sh                       # check all attendees
#     ./verify.sh --attendee 07         # check just attendee 07
# =============================================================================

set -uo pipefail

CSV_FILE="attendee-credentials.csv"
SPECIFIC_ATTENDEE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --attendee)
            SPECIFIC_ATTENDEE="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [[ ! -f "${CSV_FILE}" ]]; then
    echo "ERROR: ${CSV_FILE} not found. Run ./deploy-all.sh first." >&2
    exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
    echo "ERROR: sshpass not installed. Install with: brew install sshpass / apt install sshpass" >&2
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0
RESULTS=""

# Skip the header line, iterate over each attendee
tail -n +2 "${CSV_FILE}" | while IFS=, read -r num name control_ip ssh_user ssh_pass win_user win_pass vault_pass; do

    if [[ -n "${SPECIFIC_ATTENDEE}" && "${num}" != "${SPECIFIC_ATTENDEE}" ]]; then
        continue
    fi

    echo ""
    echo "==> Attendee ${num} (${control_ip})"

    # Check 1: SSH reachable
    if sshpass -p "${ssh_pass}" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        "${ssh_user}@${control_ip}" \
        "echo OK" >/dev/null 2>&1; then
        echo "    SSH:        ✓"
        SSH_OK=1
    else
        echo "    SSH:        ✗"
        SSH_OK=0
        ((FAIL_COUNT++)) || true
        continue
    fi

    # Check 2: Bootstrap marker
    if sshpass -p "${ssh_pass}" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${ssh_user}@${control_ip}" \
        "test -f /var/lib/cloud/instance/workshop-bootstrap-complete" 2>/dev/null; then
        echo "    Bootstrap:  ✓"
    else
        echo "    Bootstrap:  ✗"
    fi

    # Check 3: Repo cloned
    if sshpass -p "${ssh_pass}" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${ssh_user}@${control_ip}" \
        "test -f /home/${ssh_user}/workshop/ansible.cfg" 2>/dev/null; then
        echo "    Repo:       ✓"
    else
        echo "    Repo:       ✗"
    fi

    # Check 4: Ansible installed
    if sshpass -p "${ssh_pass}" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${ssh_user}@${control_ip}" \
        "ansible --version" >/dev/null 2>&1; then
        echo "    Ansible:    ✓"
    else
        echo "    Ansible:    ✗"
    fi

    # Check 5: pywinrm installed
    if sshpass -p "${ssh_pass}" ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${ssh_user}@${control_ip}" \
        "python3 -c 'import winrm'" >/dev/null 2>&1; then
        echo "    pywinrm:    ✓"
        ((PASS_COUNT++)) || true
    else
        echo "    pywinrm:    ✗"
    fi
done

echo ""
echo "============================================================"
echo "Verification complete."
echo "============================================================"
