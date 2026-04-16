#!/usr/bin/env bash
#
# capture.sh — record terminal output from a workshop command
#
# Usage:
#     ./docs/captures/capture.sh <name> <command...>
#     ./docs/captures/capture.sh --with-timing <name> <command...>
#
# Examples:
#     ./docs/captures/capture.sh section-1.4-preflight \
#         ansible-playbook preflight/check.yml
#
#     ./docs/captures/capture.sh section-2.1-web-tier \
#         ansible-playbook playbooks/02-web-tier.yml
#
# This script wraps your command in `script(1)`, the standard Linux session
# recorder. It writes the output to docs/captures/<name>.txt.
#
# We force COLUMNS=120 so captures are consistent regardless of who runs them
# or what terminal they're using.
#
# Run from the workshop root directory.

set -euo pipefail

WITH_TIMING=0
if [[ "${1:-}" == "--with-timing" ]]; then
    WITH_TIMING=1
    shift
fi

if [[ $# -lt 2 ]]; then
    cat >&2 <<'EOF'
Usage: capture.sh [--with-timing] <name> <command...>

Examples:
    capture.sh section-1.4-preflight ansible-playbook preflight/check.yml
    capture.sh --with-timing section-2.1-web-tier ansible-playbook playbooks/02-web-tier.yml

The capture is written to docs/captures/<name>.txt
EOF
    exit 1
fi

NAME="$1"
shift

CAPTURE_DIR="docs/captures"
OUTPUT_FILE="${CAPTURE_DIR}/${NAME}.txt"
TIMING_FILE="${CAPTURE_DIR}/${NAME}.timing"

# Sanity check we're in the workshop root
if [[ ! -f "ansible.cfg" ]] || [[ ! -d "${CAPTURE_DIR}" ]]; then
    echo "ERROR: Run this script from the workshop root directory." >&2
    echo "       (the directory containing ansible.cfg)" >&2
    exit 1
fi

# Force consistent terminal width
export COLUMNS=120
stty cols 120 2>/dev/null || true

echo "==> Capturing '$*' to ${OUTPUT_FILE}"
echo "    (terminal width forced to 120 columns for consistency)"
echo ""

# `script` writes a typescript of the session. We pass --quiet to suppress
# the "Script started/done" lines, --return so the exit code reflects the
# command's exit code, and --command to run the command directly.
if [[ "${WITH_TIMING}" == "1" ]]; then
    script --quiet --return --timing="${TIMING_FILE}" --command "$*" "${OUTPUT_FILE}"
    echo ""
    echo "==> Wrote ${OUTPUT_FILE} and ${TIMING_FILE}"
    echo "    To replay: scriptreplay --timing=${TIMING_FILE} ${OUTPUT_FILE}"
else
    script --quiet --return --command "$*" "${OUTPUT_FILE}"
    echo ""
    echo "==> Wrote ${OUTPUT_FILE}"
fi

echo ""
echo "==> Don't forget to:"
echo "    1. Verify the capture looks right (open it in less or cat)"
echo "    2. Redact any secrets that leaked into output"
echo "    3. Delete the corresponding .placeholder file"
echo "    4. Update docs/captures/README.md with your name and the date"
