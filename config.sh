#!/bin/bash
# =============================================================================
# filc-bootstrap - Configuration file
# =============================================================================

# ====================== Safe SCRIPT_DIR Setup ======================
# Ensure SCRIPT_DIR is always defined, even if sourced early
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        SCRIPT_DIR="$(pwd)"
    fi
fi

# ====================== Fil-C Settings ======================
export FILC_REPO="https://github.com/pizlonator/fil-c.git"
export FILC_BRANCH="deluge"
export FILC_COMMIT=""                                          # Leave empty for latest on branch
export FILC_COMMIT="39ee664dbf0b7db841ae05269201e757447290ee"  # Recent commit in deluge branch
export FILC_TAG="v0.678"
#export FILC_COMMIT="39ee664dbf0b7db841ae05269201e757447290ee" # deluge snapshot, Mar 27, 2026, LLVM 20.1.8
export FILC_USE_TAG=true                                       # Set to true if using FILC_TAG

export FILC_LIBC="glibc"
export FILC_PREFIX="/opt/fil"
export YOLO_PREFIX="/yolo"

# Build flags - control march and optimization level
export MARCH="x86-64"      # Change to x86-64-v3 or native only if you know your CPU supports it.  Upstream default is x86-64-v2.
export OPT_LEVEL="O2"         # Safer than O3. Use O3 only if you accept potential runtime issues.  Upstream default is -O3.

# ====================== Git Optimization ======================
export GIT_SHALLOW=false
export GIT_CACHE_DIR="$HOME/.cache/filc-git-cache"

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

# ====================== Logging Function ======================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/bootstrap.log" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ====================== Configuration Summary ======================
log_config() {
    echo "=== filc-bootstrap Configuration ==="
    echo "Fil-C branch     : ${FILC_BRANCH}"
    if [[ -n "${FILC_COMMIT}" ]]; then
        echo "Fil-C commit     : ${FILC_COMMIT} (pinned)"
    elif [[ "$FILC_USE_TAG" == "true" && -n "${FILC_TAG}" ]]; then
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

# ====================== Load Hooks ======================
for hook_file in "hooks_requirements.sh" "hooks_chroot_setup.sh" "hooks_handoff.sh"; do
    if [[ -f "$SCRIPT_DIR/$hook_file" ]]; then
        source "$SCRIPT_DIR/$hook_file"
        log "$hook_file loaded successfully."
    elif [[ -f "$HOST_SCRIPT_DIR/$hook_file" ]]; then
        source "$HOST_SCRIPT_DIR/$hook_file"
        log "$hook_file loaded from host path."
    else
        log "WARNING: $hook_file not found. Some functionality may be missing."
    fi
done

log_config
