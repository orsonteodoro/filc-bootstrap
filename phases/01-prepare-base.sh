#!/bin/bash
# =============================================================================
# Phase 01 - Prepare Base Environment (with git progress + cache)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 01] $*"
}

log "Starting Phase 01: Prepare Base Environment"

# Ensure scripts are in place
cd /root/filc-bootstrap || {
    mkdir -p /root/filc-bootstrap
    cp -a "$SCRIPT_DIR"/.. /root/filc-bootstrap/
    cd /root/filc-bootstrap
}

# ====================== Git Cache Setup (for faster repeats) ======================
mkdir -p "$GIT_CACHE_DIR"

# ====================== Clone / Update Fil-C with progress ======================
log "Setting up Fil-C at $FILC_SOURCE_DIR"

if [[ -d "$FILC_SOURCE_DIR/.git" ]]; then
    log "Updating existing Fil-C repository..."
    cd "$FILC_SOURCE_DIR"
    git fetch --progress origin
    git checkout "$FILC_BRANCH"
    if [[ -n "$FILC_COMMIT" ]]; then
        git checkout "$FILC_COMMIT"
    fi
    git pull --ff-only --progress || true
else
    log "Cloning Fil-C repository (this may take a while on first run)..."
    mkdir -p "$(dirname "$FILC_SOURCE_DIR")"

    CLONE_OPTS="--progress"
    [[ "$GIT_SHALLOW" == "true" ]] && CLONE_OPTS="$CLONE_OPTS --depth 1"

    git clone $CLONE_OPTS --branch "$FILC_BRANCH" "$FILC_REPO" "$FILC_SOURCE_DIR"

    cd "$FILC_SOURCE_DIR"
    if [[ -n "$FILC_COMMIT" ]]; then
        log "Pinning to commit: $FILC_COMMIT"
        git checkout "$FILC_COMMIT"
    fi
fi

# Verify clone succeeded
if [[ ! -f "$FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "ERROR: Fil-C build scripts not found after clone!"
    exit 1
fi

log "Fil-C source ready at $FILC_SOURCE_DIR"
log "Current commit: $(git rev-parse --short HEAD) ($(git log -1 --format=%s))"

# ====================== Rest of Phase 01 (dependencies) ======================
log "Installing build dependencies..."

if [[ -f /etc/alpine-release ]]; then
    apk add --no-cache \
        bash git curl wget ca-certificates \
        build-base clang clang-dev llvm llvm-dev \
        cmake ninja patchelf rsync tar
elif [[ -f /etc/gentoo-release ]]; then
    emerge --sync --quiet || log "WARNING: emerge --sync failed"
    emerge -av --noreplace git clang llvm cmake ninja patchelf quilt rsync tar wget curl
fi

log "Phase 01 completed successfully!"
log "Ready for Phase 02 (Fil-C build)."

exit 0
