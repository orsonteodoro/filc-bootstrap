#!/bin/bash
# =============================================================================
# filc-bootstrap - Configuration file
# =============================================================================

# ====================== Fil-C Settings ======================
export FILC_REPO="https://github.com/pizlonator/fil-c.git"
export FILC_BRANCH="deluge"

# === Pinning Strategy ===
# For maximum reproducibility (recommended for testing):
#   Use a specific commit hash.
#
# For system-wide / daily use:
#   Use "latest" or a recent stable tag if available.
export FILC_COMMIT=""                                          # Leave empty for latest on branch
export FILC_COMMIT="39ee664dbf0b7db841ae05269201e757447290ee"  # Recent commit in deluge branch
export FILC_TAG="v0.678"
#export FILC_COMMIT="39ee664dbf0b7db841ae05269201e757447290ee" # deluge snapshot, Mar 27, 2026, LLVM 20.1.8
export FILC_USE_TAG=true                                       # Set to true if using FILC_TAG

# Alternative: Use latest tag (less reproducible but more "stable")
# export FILC_USE_LATEST_TAG=true

export FILC_LIBC="glibc"                       # glibc (recommended) or musl
export FILC_PREFIX="/opt/fil"
export YOLO_PREFIX="/yolo"

# ====================== Build Settings ======================
export MAKEOPTS="-j$(nproc)"
export CFLAGS="-O2 -pipe -fPIC"
export CXXFLAGS="${CFLAGS}"

# Directories
export LOG_DIR="./logs"
export CHECKPOINT_DIR="./checkpoints"
export BACKUP_DIR="./backups"
export FILC_SOURCE_DIR="/root/filc-bootstrap/sources/fil-c"

# ====================== Safety & Recovery ======================
export CREATE_SNAPSHOTS=true
export SNAPSHOT_PREFIX="filc-snapshot"

# ====================== Test Mode ======================
export TEST_MODE=${TEST_MODE:-false}
export TEST_DISTRO=${TEST_DISTRO:-"debian"}

# Gentoo-specific
export SKIP_GENTOO_BRIDGE=false

# Force flags
export FORCE_FRESH=${FORCE_FRESH:-false}

# ====================== Git Optimization ======================
# Disable shallow clone when using a pinned commit or tag
if [[ -n "$FILC_COMMIT" || "$FILC_USE_TAG" == "true" ]]; then
    export GIT_SHALLOW=false
else
    export GIT_SHALLOW=true
fi

# ====================== Git Cache for Reproducibility ======================
export GIT_SHALLOW=true # May break
export GIT_CACHE_DIR="${GIT_CACHE_DIR:-$HOME/.cache/filc-git-cache}"
mkdir -p "$GIT_CACHE_DIR"

# Use reference cache to avoid re-downloading
export GIT_CLONE_FLAGS="--progress"
if [[ "$GIT_SHALLOW" == "true" ]]; then
    export GIT_CLONE_FLAGS="$GIT_CLONE_FLAGS --depth 1"
fi

# ====================== Load Hooks ======================
# Centralized hook file (like requirements.txt)
if [[ -f "$SCRIPT_DIR/hooks.sh" ]]; then
    source "$SCRIPT_DIR/hooks.sh"
else
    log "WARNING: hooks.sh not found. Distro-specific support may be missing."
fi

# ====================== Logging ======================
log_config() {
    echo "=== filc-bootstrap Configuration ==="
    echo "Fil-C branch     : ${FILC_BRANCH}"
    if [[ -n "${FILC_COMMIT}" ]]; then
        echo "Fil-C commit     : ${FILC_COMMIT} (pinned)"
    elif [[ -n "${FILC_TAG}" && "${FILC_USE_TAG}" == "true" ]]; then
        echo "Fil-C tag        : ${FILC_TAG}"
    else
        echo "Fil-C commit     : tip of ${FILC_BRANCH}"
    fi
    echo "Fil-C libc       : ${FILC_LIBC}"
    echo "Fil-C prefix     : ${FILC_PREFIX}"

    if [[ "$TEST_MODE" == "true" ]]; then
        echo "Test mode        : ENABLED (${TEST_DISTRO})"
    else
        echo "Test mode        : DISABLED (using Gentoo stage 3)"
    fi

    echo "MAKEOPTS         : ${MAKEOPTS}"
    echo "====================================="
}
###
