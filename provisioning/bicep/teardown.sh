#!/usr/bin/env bash
#
# teardown.sh — Delete every workshop resource group
#
# Bicep equivalent of `ansible-playbook teardown.yml`. Finds all resource
# groups matching the workshop naming pattern and deletes them. Prompts for
# confirmation before doing anything destructive.
#
# Usage:
#     ./teardown.sh                   # interactive, prompts for confirmation
#     ./teardown.sh --yes             # non-interactive, dangerous
# =============================================================================

set -euo pipefail

WORKSHOP_NAME_PREFIX="workshop-att-"
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

echo "==> Searching for workshop resource groups..."
RGS=$(az group list --query "[?starts_with(name, '${WORKSHOP_NAME_PREFIX}')].name" -o tsv)

if [[ -z "${RGS}" ]]; then
    echo "    No workshop resource groups found. Nothing to do."
    exit 0
fi

echo ""
echo "Found the following workshop resource groups:"
echo "${RGS}" | sed 's/^/  - /'
echo ""

if [[ "${SKIP_CONFIRM}" != "true" ]]; then
    echo "About to DELETE all of the above. This is irreversible."
    read -r -p 'Type "DELETE" (in capitals) to confirm: ' CONFIRMATION
    if [[ "${CONFIRMATION}" != "DELETE" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo ""
echo "==> Deleting resource groups (in parallel, no-wait)..."

# Use --no-wait so all deletes start in parallel. Azure handles them in the
# background. Then poll until they're all gone.
while IFS= read -r rg; do
    echo "    Deleting ${rg}..."
    az group delete --name "${rg}" --yes --no-wait
done <<< "${RGS}"

echo ""
echo "==> All deletion requests submitted. Polling until complete..."

while true; do
    REMAINING=$(az group list --query "[?starts_with(name, '${WORKSHOP_NAME_PREFIX}')].name" -o tsv | wc -l)
    if [[ "${REMAINING}" -eq 0 ]]; then
        break
    fi
    echo "    ${REMAINING} resource groups still deleting..."
    sleep 30
done

echo ""
echo "============================================================"
echo "Teardown complete. All workshop resource groups deleted."
echo ""
echo "Don't forget to securely delete the credentials file:"
echo "    shred -u attendee-credentials.csv"
echo "============================================================"
