#!/bin/bash
# =============================================================================
# filc-bootstrap - Main bootstrap driver (Fixed unbound variable + clean logic)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source ./config.sh || {
    echo "ERROR: config.sh not found!"
    exit 1
}

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
TEST_DISTRO="alpine"
SKIP_CLEAN_SLATE=false
UPDATE_FILC_ONLY=false
RECOVER_LC=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fresh)            FORCE_FRESH=true ;;
        --test)             TEST_MODE=true ;;
        --test-debian)      TEST_MODE=true; TEST_DISTRO="debian" ;;
        --test-alpine)      TEST_MODE=true; TEST_DISTRO="alpine" ;;
        --clean-slate)      TEST_MODE=false ;;
        --skip-clean-slate) SKIP_CLEAN_SLATE=true ;;
        --update-filc)      UPDATE_FILC_ONLY=true ;;
        --recover-lc)       RECOVER_LC=true ;;
        --help|-h)
            echo "Usage: ./bootstrap.sh [OPTIONS]"
            echo "  --test              Fast test with Debian"
            echo "  --test-alpine       Fast test with Alpine"
            echo "  --clean-slate       Full Gentoo stage 3 build"
            echo "  --fresh             Ignore checkpoints"
            echo "  --skip-clean-slate  Skip Phase 00 (used internally)"
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

# If we are inside chroot and told to skip Phase 00
if [[ "$SKIP_CLEAN_SLATE" == "true" ]]; then
    log "Skipping Phase 00 (--skip-clean-slate). Running inner phases directly."

    if [[ "$UPDATE_FILC_ONLY" == "true" ]]; then
        run_phase "./phases/02-build-filc-toolchain.sh"
        run_phase "./phases/03-setup-dual-libc.sh"
    elif [[ "$RECOVER_LC" == "true" ]]; then
        run_phase "./phases/03-setup-dual-libc.sh"
    else
        run_phase "./phases/01-prepare-base.sh"
        run_phase "./phases/02-build-filc-toolchain.sh"
        run_phase "./phases/03-setup-dual-libc.sh"
        run_phase "./phases/03.5-test-hello-world.sh"

        if [[ -f /etc/gentoo-release && "$SKIP_GENTOO_BRIDGE" != "true" ]]; then
            run_phase "./phases/04-gentoo-bridge.sh"
        fi
    fi

    log "Bootstrap completed successfully (inner phases only)"
    exit 0
fi

# Normal flow - start with Phase 00
log "Starting normal flow with Phase 00"
./phases/00-setup-clean-slate.sh "$@"

exit 0
