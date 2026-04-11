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
#export FILC_COMMIT=""                          # Leave empty to use tip of branch
#export FILC_COMMIT="39ee664dbf0b7db841ae05269201e757447290ee" # deluge snapshot, Mar 27, 2026, LLVM 20.1.8
export FILC_COMMIT="8122d8c2d7cff174c30041c0f7542d57feaecc3d" # v0.678, Feb 10, 2026, LLVM 20.1.8

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
export FILC_SOURCE_DIR="./sources/fil-c"

# ====================== Safety & Recovery ======================
export CREATE_SNAPSHOTS=true
export SNAPSHOT_PREFIX="filc-snapshot"

# ====================== Test Mode ======================
export TEST_MODE=${TEST_MODE:-false}
export TEST_DISTRO=${TEST_DISTRO:-"alpine"}

# Gentoo-specific
export SKIP_GENTOO_BRIDGE=false

# Force flags
export FORCE_FRESH=${FORCE_FRESH:-false}

# ====================== Git Clone Optimization ======================
# Use shallow clone + shared cache for faster, more hermetic repeats
export GIT_SHALLOW=true
export GIT_CACHE_DIR="$HOME/.cache/filc-git-cache"

# ====================== Logging ======================
log_config() {
    echo "=== filc-bootstrap Configuration ==="
    echo "Fil-C branch     : ${FILC_BRANCH}"
    if [[ -n "${FILC_COMMIT}" ]]; then
        echo "Fil-C commit     : ${FILC_COMMIT} (pinned)"
    else
        echo "Fil-C commit     : tip of ${FILC_BRANCH} (not pinned)"
    fi
    echo "Fil-C libc       : ${FILC_LIBC}"
    echo "Fil-C prefix     : ${FILC_PREFIX}"
    echo "Test mode        : ${TEST_MODE} (${TEST_DISTRO})"
    echo "MAKEOPTS         : ${MAKEOPTS}"
    echo "====================================="
}
###
