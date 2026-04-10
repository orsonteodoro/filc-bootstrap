#!/bin/bash
# =============================================================================
# filc-bootstrap - Main bootstrap driver
# Supports clean Gentoo stage 3 + fast test mode (Debian / Alpine)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load configuration
if [[ ! -f ./config.sh ]]; then
    echo "ERROR: config.sh not found!"
    exit 1
fi
source ./config.sh

# Create directories
mkdir -p "$LOG_DIR" "$CHECKPOINT_DIR" "$BACKUP_DIR" "$FILC_SOURCE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/bootstrap.log"
}

run_phase() {
    local phase_file="$1"
    local phase_name="$(basename "$phase_file" .sh)"

    if [[ -f "$CHECKPOINT_DIR/${phase_name}.done" ]] && [[ "$FORCE_FRESH" != "true" ]]; then
        log "Phase $phase_name already completed. Skipping."
        return 0
    fi

    log "=== Starting phase: $phase_name ==="

    if [[ ! -f "$phase_file" ]]; then
        log "ERROR: Phase script $phase_file not found!"
        exit 1
    fi

    if "$phase_file" 2>&1 | tee "$LOG_DIR/${phase_name}.log"; then
        touch "$CHECKPOINT_DIR/${phase_name}.done"
        log "=== Phase $phase_name completed successfully ==="
    else
        log "=== Phase $phase_name FAILED ==="
        exit 1
    fi
}

# ====================== Argument Parsing ======================
FORCE_FRESH=false
TEST_MODE=false
TEST_DISTRO="debian"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fresh)           FORCE_FRESH=true ;;
        --test)            TEST_MODE=true ;;
        --test-debian)     TEST_MODE=true; TEST_DISTRO="debian" ;;
        --test-alpine)     TEST_MODE=true; TEST_DISTRO="alpine" ;;
        --clean-slate)     TEST_MODE=false ;;   # Force real Gentoo
        --update-filc)     UPDATE_FILC_ONLY=true ;;
        --recover-lc)      RECOVER_LC=true ;;
        --help|-h)
            echo "Usage: ./bootstrap.sh [OPTIONS]"
            echo ""
            echo "Test modes (fast validation):"
            echo "  --test              Test with Debian (default)"
            echo "  --test-debian       Test with Debian"
            echo "  --test-alpine       Test with Alpine"
            echo ""
            echo "Real build:"
            echo "  --clean-slate       Use clean Gentoo stage 3"
            echo "  --fresh             Ignore checkpoints"
            echo ""
            echo "Advanced:"
            echo "  --update-filc       Only update Fil-C toolchain"
            echo "  --recover-lc        Recover LC phase only"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

log "filc-bootstrap started"
log_config

# Set test mode variables for Phase 00
if [[ "$TEST_MODE" == "true" ]]; then
    export TEST_MODE=true
    export TEST_DISTRO="$TEST_DISTRO"
    log "=== TEST MODE ENABLED ($TEST_DISTRO) ==="
fi

# ====================== Launch Phase 00 ======================
log "Starting Phase 00 (Clean Slate / Chroot Setup)"
./phases/00-setup-clean-slate.sh "$@"

exit 0
