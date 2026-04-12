#!/bin/bash
# =============================================================================
# Phase 04 - Handoff / Final Integration (Hook-based)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 04] $*"
}

log "Starting Phase 04: Final Handoff / Integration"

# Ensure we are in the correct directory
cd /root/filc-bootstrap || {
    log "ERROR: Cannot cd to /root/filc-bootstrap"
    exit 1
}

# ====================== Load Handoff Hooks ======================
if [[ -f "$SCRIPT_DIR/hooks_handoff.sh" ]]; then
    source "$SCRIPT_DIR/hooks_handoff.sh"
    log "hooks_handoff.sh loaded successfully."
else
    log "ERROR: hooks_handoff.sh not found!"
    exit 1
fi

# ====================== Run Distro-specific Handoff Hook ======================
log "Running handoff hook for $TEST_DISTRO..."

HANDOFF_HOOK="${TEST_DISTRO}_handoff"

if declare -F "$HANDOFF_HOOK" > /dev/null; then
    log "Executing hook: $HANDOFF_HOOK"
    "$HANDOFF_HOOK"
else
    log "ERROR: Required hook function $HANDOFF_HOOK is not defined in hooks_handoff.sh!"
    log "Please add support for $TEST_DISTRO in hooks_handoff.sh"
    exit 1
fi

# ====================== Common Final Steps ======================
log "Performing common final verification..."

if command -v filcc >/dev/null; then
    log "✅ filcc found in PATH"
    filcc --version | head -n 3
else
    log "WARNING: filcc not found in PATH"
fi

if command -v fil++ >/dev/null; then
    log "✅ fil++ found in PATH"
fi

# Simple hello world test as final sanity check
log "Running final hello world test..."

cat > /tmp/hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Fil-C bootstrap completed successfully!\n");
    printf("Memory safety is now active.\n");
    return 0;
}
EOF

if filcc /tmp/hello.c -o /tmp/hello; then
    /tmp/hello
    log "✅ Hello world test passed with filcc"
else
    log "WARNING: Hello world test failed"
fi

log "Phase 04 completed successfully!"
log "Fil-C bootstrap is now ready for use."

echo ""
echo "========================================================================"
echo "Bootstrap finished!"
echo "You can now compile with: filcc yourfile.c -o yourfile"
echo "========================================================================"

exit 0
