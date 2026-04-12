#!/bin/bash
# =============================================================================
# Phase 01 - Prepare Base Environment (Missing hooks are fatal)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 01] $*"
}

log "Starting Phase 01: Prepare Base Environment"

# Ensure we are in the chroot and scripts are in place
cd /root/filc-bootstrap || {
    mkdir -p /root/filc-bootstrap
    cp -a "$SCRIPT_DIR"/.. /root/filc-bootstrap/ 2>/dev/null || true
    cd /root/filc-bootstrap
}

# ====================== Distro Detection ======================
if [[ -f /etc/gentoo-release ]]; then
    DISTRO="gentoo"
    log "Detected Gentoo"
elif [[ -f /etc/alpine-release ]]; then
    DISTRO="alpine"
    log "Detected Alpine"
elif [[ -f /etc/debian_version ]]; then
    DISTRO="debian"
    log "Detected Debian"
else
    DISTRO="unknown"
    log "WARNING: Unknown distribution"
fi

# ====================== DNS Verification ======================
log "Verifying DNS resolution..."
if ! ping -c 1 -W 5 -q google.com >/dev/null 2>&1; then
    log "DNS failed. Applying fallback..."
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    chmod 644 /etc/resolv.conf
fi
log "DNS is working."

# ====================== Run Distro-specific prepare_deps Hook ======================
log "Running prepare_deps hook for $DISTRO..."

HOOK_FUNC="${DISTRO}_prepare_deps"

if declare -F "$HOOK_FUNC" > /dev/null; then
    log "Executing hook: $HOOK_FUNC"
    "$HOOK_FUNC"
else
    log "ERROR: Required hook function $HOOK_FUNC is not defined in hooks.sh!"
    log "Please add support for $DISTRO in hooks.sh"
    exit 1
fi

log "Dependencies installation completed via hook."

# Verify critical tools
for tool in git clang cmake ninja; do
    if ! command -v "$tool" >/dev/null; then
        log "ERROR: Required tool '$tool' is still not available after hook execution"
        exit 1
    fi
done
log "✅ Core tools (git, clang, cmake, ninja) are available."

# ====================== Clone / Update Fil-C ======================
log "Setting up Fil-C source at $FILC_SOURCE_DIR"

ABS_FILC_SOURCE_DIR="/root/filc-bootstrap/sources/fil-c"

if [[ -d "$ABS_FILC_SOURCE_DIR/.git" ]]; then
    log "Updating existing Fil-C repository..."
    cd "$ABS_FILC_SOURCE_DIR"
    git fetch --progress origin
else
    log "Cloning Fil-C repository..."
    mkdir -p "$(dirname "$ABS_FILC_SOURCE_DIR")"
    git clone --progress --depth 1 --branch "$FILC_BRANCH" "$FILC_REPO" "$ABS_FILC_SOURCE_DIR"
    cd "$ABS_FILC_SOURCE_DIR"
fi

git checkout "$FILC_BRANCH" || true

if [[ -n "$FILC_COMMIT" ]]; then
    log "Pinning to commit: $FILC_COMMIT"
    git fetch origin "$FILC_COMMIT" || true
    git checkout "$FILC_COMMIT" || log "WARNING: Commit not found"
fi

if [[ ! -f "$ABS_FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "ERROR: Fil-C build scripts still not found!"
    ls -la "$ABS_FILC_SOURCE_DIR"
    exit 1
fi

log "Fil-C source ready."
log "Current commit: $(git rev-parse --short HEAD) - $(git log -1 --oneline)"

# ====================== Snapshot ======================
if [[ "$CREATE_SNAPSHOTS" == "true" ]]; then
    SNAPSHOT_NAME="${SNAPSHOT_PREFIX}-post-phase01-$(date '+%Y%m%d-%H%M%S').tar.gz"
    log "Creating post-phase01 snapshot..."
    mkdir -p "$BACKUP_DIR"
    tar -czf "$BACKUP_DIR/$SNAPSHOT_NAME" \
        --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp \
        /bin /usr/bin /lib /usr/lib /etc 2>/dev/null || true
fi

# ====================== Load Hooks ======================
# Like requirements.txt - all distro hooks are centralized here
if [[ -f "$SCRIPT_DIR/hooks.sh" ]]; then
    source "$SCRIPT_DIR/hooks.sh"
else
    log "WARNING: hooks.sh not found. Some distro support may be missing."
    exit 1
fi

log "Phase 01 completed successfully!"
log "Ready for Phase 02: Building Fil-C toolchain."

exit 0
