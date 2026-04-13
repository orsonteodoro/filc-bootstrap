#!/bin/bash
# =============================================================================
# filc-bootstrap - Main bootstrap driver
# =============================================================================

set -euo pipefail

# === CRITICAL: Set SCRIPT_DIR VERY EARLY ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Now source config (which loads all hooks)
source ./config.sh

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [bootstrap] $*"
}

log "Starting filc-bootstrap"

# Parse arguments
FORCE_FRESH=false
TEST_MODE=false
TEST_DISTRO="debian"
SKIP_CLEAN_SLATE=false
UPDATE_FILC_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fresh)
            FORCE_FRESH=true
            shift
            ;;
        --test-debian)
            TEST_MODE=true
            TEST_DISTRO="debian"
            shift
            ;;
        --test-alpine)
            TEST_MODE=true
            TEST_DISTRO="alpine"
            shift
            ;;
        --skip-clean-slate)
            SKIP_CLEAN_SLATE=true
            shift
            ;;
        --update-filc-only)
            UPDATE_FILC_ONLY=true
            shift
            ;;
        *)
            log "Unknown option: $1"
            exit 1
            ;;
    esac
done

export FORCE_FRESH TEST_MODE TEST_DISTRO SKIP_CLEAN_SLATE UPDATE_FILC_ONLY

# Create log directory
mkdir -p "$LOG_DIR"

log_config

# ====================== Phase Runner ======================
run_phase() {
    local phase_file="phases/$1"
    if [[ -f "$phase_file" ]]; then
        log "=== Starting Phase: $1 ==="
        bash "$phase_file"
        log "=== Phase $1 completed successfully ==="
    else
        log "ERROR: Phase file $phase_file not found!"
        exit 1
    fi
}

# ====================== Main Bootstrap Flow ======================

if [[ "$SKIP_CLEAN_SLATE" != "true" ]]; then
    log "Running Phase 00: Clean Slate Setup"
    bash phases/00-setup-clean-slate.sh "$@"
    # Phase 00 will chroot and continue execution
    exit 0
fi

# If we reach here, we are inside the chroot
log "Inside chroot - continuing bootstrap"

# Phase 01: Prepare base + dependencies
run_phase "01-prepare-base.sh"

# Phase 02: Build Fil-C toolchain
run_phase "02-build-filc-toolchain.sh"

# Phase 04: Final handoff (via hooks_handoff.sh)
log "=== Starting Phase 04: Final Handoff ==="
run_phase "04-handoff.sh"

log "========================================================================"
log "filc-bootstrap completed successfully!"
log "You can now use: filcc yourfile.c -o yourfile"
log "========================================================================"

exit 0
