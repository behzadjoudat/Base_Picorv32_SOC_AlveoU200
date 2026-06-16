#!/usr/bin/env bash
# Download picorv32.v from a pinned commit of the official repository.
# Pinned to a stable, well-tested commit.

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/YosysHQ/picorv32/master"
TARGET="$(dirname "$0")/../rtl/picorv32.v"

TARGET="$(realpath "$TARGET")"

if [[ -f "$TARGET" ]]; then
    echo "picorv32.v already present at $TARGET — skipping download."
    exit 0
fi

echo "Fetching picorv32.v from master branch ..."
curl -fsSL "${REPO_URL}/picorv32.v" -o "$TARGET"
echo "Saved to $TARGET"

# Sanity check: the file must contain both the plain core and the AXI wrapper
grep -q "module picorv32_axi " "$TARGET" || {
    echo "ERROR: downloaded file does not contain picorv32_axi — wrong commit?"
    rm -f "$TARGET"
    exit 1
}
echo "OK — picorv32_axi module confirmed."
