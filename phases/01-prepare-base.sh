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

# ====================== Clone / Update Fil-C (with cache) ======================
log "Setting up Fil-C source at $FILC_SOURCE_DIR"

# Use git cache to avoid re-downloading on every fresh run
if [[ ! -d "$FILC_SOURCE_DIR/.git" ]]; then
    log "Cloning Fil-C (using cache if available)..."

    mkdir -p "$(dirname "$FILC_SOURCE_DIR")"

    if [[ -d "$GIT_CACHE_DIR/fil-c.git" ]]; then
        log "Using existing git cache at $GIT_CACHE_DIR/fil-c.git"
        git clone --reference "$GIT_CACHE_DIR/fil-c.git" --progress "$FILC_REPO" "$FILC_SOURCE_DIR"
    else
        git clone --progress "$FILC_REPO" "$FILC_SOURCE_DIR"
        # Create cache for future runs
        cp -a "$FILC_SOURCE_DIR/.git" "$GIT_CACHE_DIR/fil-c.git" 2>/dev/null || true
    fi

    cd "$FILC_SOURCE_DIR"
else
    log "Updating existing Fil-C repository..."
    cd "$FILC_SOURCE_DIR"
    git fetch --progress origin
fi

# Checkout logic
git checkout "$FILC_BRANCH" || true

if [[ "$FILC_USE_TAG" == "true" && -n "$FILC_TAG" ]]; then
    log "Checking out tag: $FILC_TAG"
    git fetch --tags --progress
    git checkout "$FILC_TAG" || log "WARNING: Tag $FILC_TAG not found"
elif [[ -n "$FILC_COMMIT" ]]; then
    log "Pinning to commit: $FILC_COMMIT"
    git fetch origin "$FILC_COMMIT" || true
    git checkout "$FILC_COMMIT" || log "WARNING: Commit $FILC_COMMIT not found, staying on branch tip"
fi

# Final verification with recovery
if [[ ! -f "$FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "WARNING: build scripts not found. Resetting to branch tip..."
    git checkout "$FILC_BRANCH"
    git pull --ff-only --progress || true
fi

if [[ ! -f "$FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "ERROR: Fil-C build scripts still not found!"
    log "Current directory: $(pwd)"
    ls -la
    exit 1
fi

log "Fil-C source ready."
log "Current commit: $(git rev-parse --short HEAD) - $(git log -1 --oneline)"

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
