#!/bin/bash
# =============================================================================
# Phase 00 - Setup Clean Slate (Hook-based chroot setup)
# =============================================================================

set -euo pipefail

# Calculate host paths VERY EARLY
HOST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
HOST_BOOTSTRAP_PATH="$HOST_SCRIPT_DIR"

# Source config (which will load hooks_requirements.sh)
source "$HOST_SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 00] $*"
}

log "Starting Phase 00: Clean Slate Setup"

TARGET_ROOT="${TARGET_ROOT:-/mnt/filc-chroot}"
TEST_MODE=${TEST_MODE:-false}
TEST_DISTRO=${TEST_DISTRO:-"debian"}

log "Target root: $TARGET_ROOT | Mode: $TEST_MODE ($TEST_DISTRO)"

# ====================== Load Chroot Setup Hooks ======================
if [[ -f "$HOST_SCRIPT_DIR/hooks_chroot_setup.sh" ]]; then
    source "$HOST_SCRIPT_DIR/hooks_chroot_setup.sh"
    log "hooks_chroot_setup.sh loaded successfully."
else
    log "ERROR: hooks_chroot_setup.sh not found!"
    exit 1
fi

# ====================== Safe Fresh Wipe ======================
if [[ "$FORCE_FRESH" == "true" ]]; then
    log "Force fresh enabled — preparing to wipe $TARGET_ROOT"

    if [[ "$TARGET_ROOT" == "/" || "$TARGET_ROOT" == "/home" || "$TARGET_ROOT" == "/root" || -z "$TARGET_ROOT" ]]; then
        log "ERROR: Refusing to wipe dangerous path"
        exit 1
    fi

    log "Unmounting filesystems under $TARGET_ROOT..."
    for dir in proc sys dev run; do
        if mountpoint -q "$TARGET_ROOT/$dir" 2>/dev/null; then
            umount "$TARGET_ROOT/$dir" 2>/dev/null || true
        fi
    done

    for dir in proc sys dev run; do
        if mountpoint -q "$TARGET_ROOT/$dir" 2>/dev/null; then
            umount -l "$TARGET_ROOT/$dir" 2>/dev/null || true
        fi
    done

    log "Wiping target directory..."
    rm -rf "$TARGET_ROOT"/* 2>/dev/null || true
fi

mkdir -p "$TARGET_ROOT"

# ====================== Run Distro-specific Chroot Setup Hook ======================
log "Running chroot setup hook for $TEST_DISTRO..."

CHROOT_HOOK="${TEST_DISTRO}_chroot_setup"

if declare -F "$CHROOT_HOOK" > /dev/null; then
    log "Executing hook: $CHROOT_HOOK"
    "$CHROOT_HOOK"
else
    log "ERROR: Required hook function $CHROOT_HOOK is not defined in hooks_chroot_setup.sh!"
    exit 1
fi

# ====================== Reliable Script Copy + Consistency Check ======================
log "Copying filc-bootstrap scripts into chroot..."

mkdir -p "$TARGET_ROOT/root/filc-bootstrap"

# Safe removal: only delete script files, protect sources/, cache, checkpoints
find "$TARGET_ROOT/root/filc-bootstrap" -maxdepth 1 -type f \( -name "*.sh" -o -name "config.sh" -o -name "hooks_*.sh" \) -delete 2>/dev/null || true

log "Copying fresh scripts from host..."
cp -aT "$HOST_SCRIPT_DIR" "$TARGET_ROOT/root/filc-bootstrap" || {
    log "WARNING: cp -aT failed, trying fallback..."
    cp -a "$HOST_SCRIPT_DIR"/. "$TARGET_ROOT/root/filc-bootstrap/" 2>/dev/null || true
}

# Consistency check
log "Verifying script consistency..."
HOST_HASH=$(find "$HOST_SCRIPT_DIR" -maxdepth 1 -type f \( -name "*.sh" -o -name "config.sh" -o -name "hooks_*.sh" \) -exec sha256sum {} + 2>/dev/null | sort | sha256sum | awk '{print $1}')
CHROOT_HASH=$(find "$TARGET_ROOT/root/filc-bootstrap" -maxdepth 1 -type f \( -name "*.sh" -o -name "config.sh" -o -name "hooks_*.sh" \) 2>/dev/null | xargs sha256sum 2>/dev/null | sort | sha256sum | awk '{print $1}' || echo "failed")

if [[ "$HOST_HASH" == "$CHROOT_HASH" && "$CHROOT_HASH" != "failed" ]]; then
    log "✅ Script consistency check passed"
else
    log "⚠️  WARNING: Script inconsistency detected between host and chroot"
fi

# Final critical file check
if [[ ! -f "$TARGET_ROOT/root/filc-bootstrap/bootstrap.sh" || \
      ! -f "$TARGET_ROOT/root/filc-bootstrap/config.sh" ]]; then
    log "ERROR: Core scripts missing in chroot after copy"
    ls -la "$TARGET_ROOT/root/filc-bootstrap/"
    exit 1
fi

log "✅ All core scripts copied successfully"

# ====================== Chroot into environment ======================
log "Chrooting into clean environment..."

exec chroot "$TARGET_ROOT" /bin/bash <<'CHROOT_EOF'
    set -euo pipefail

    cd /root/filc-bootstrap

    echo "=== Inside chroot diagnostics ==="
    echo "Current directory: $(pwd)"
    ls -la

    if [[ -f bootstrap.sh ]]; then
        echo "✅ bootstrap.sh FOUND"
    else
        echo "ERROR: bootstrap.sh NOT FOUND!"
        exit 1
    fi

    echo "Starting main bootstrap..."
    exec ./bootstrap.sh --skip-clean-slate "$@"
CHROOT_EOF

exit 0
