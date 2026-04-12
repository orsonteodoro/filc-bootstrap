#!/bin/bash
# =============================================================================
# Phase 01 - Prepare Base Environment (git installed FIRST)
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

# ====================== Install git FIRST (Critical) ======================
log "Installing git first (required for cloning Fil-C)..."

if [[ "$DISTRO" == "alpine" ]]; then
    apk update
    apk add --no-cache git bash ca-certificates
elif [[ "$DISTRO" == "debian" ]]; then
    apt-get update --allow-releaseinfo-change || true
    apt-get install -y --no-install-recommends git curl wget ca-certificates
elif [[ "$DISTRO" == "gentoo" ]]; then
    emerge --sync --quiet || log "WARNING: emerge --sync failed"
    emerge -av --noreplace git
else
    log "WARNING: Unknown distro. Trying to install git..."
    command -v apt-get && apt-get install -y git || true
    command -v apk && apk add --no-cache git || true
fi

# Verify git is available
if ! command -v git >/dev/null; then
    log "ERROR: git is still not available after installation attempt"
    exit 1
fi
log "✅ git is available."

# ====================== Install Remaining Dependencies ======================
log "Installing remaining build dependencies..."

if [[ "$DISTRO" == "alpine" ]]; then
    apk add --no-cache \
        curl wget build-base clang clang-dev llvm llvm-dev llvm-static llvm-libs \
        cmake ninja \
        patchelf rsync tar \
        libxml2-dev curl-dev \
        openssl-dev zlib-dev \
        ncurses-dev readline-dev libedit-dev \
        libffi-dev python3-dev \
        bison flex \
        pkgconf

elif [[ "$DISTRO" == "debian" ]]; then
    apt-get install -y --no-install-recommends \
        build-essential clang llvm llvm-dev libclang-dev \
        cmake ninja-build \
        autoconf automake libtool bison flex gawk texinfo \
        patchelf quilt rsync tar \
        libxml2-dev libcurl4-openssl-dev \
        libssl-dev zlib1g-dev \
        libncurses5-dev libreadline-dev libedit-dev \
        libffi-dev python3-dev \
        pkg-config

elif [[ "$DISTRO" == "gentoo" ]]; then
    emerge -av --noreplace \
        clang llvm cmake ninja \
        autoconf automake libtool bison flex gawk texinfo \
        patchelf quilt rsync tar wget curl \
        sys-devel/gcc sys-libs/glibc
fi

log "Build dependencies installed."

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

# Checkout logic
git checkout "$FILC_BRANCH" || true

if [[ -n "$FILC_COMMIT" ]]; then
    log "Pinning to commit: $FILC_COMMIT"
    git fetch origin "$FILC_COMMIT" || true
    git checkout "$FILC_COMMIT" || log "WARNING: Commit not found"
fi

# Final verification
if [[ ! -f "$ABS_FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "WARNING: build scripts not found. Resetting to branch tip..."
    git checkout "$FILC_BRANCH"
    git pull --ff-only --progress || true
fi

if [[ ! -f "$ABS_FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "ERROR: Fil-C build scripts still not found!"
    log "Expected path: $ABS_FILC_SOURCE_DIR"
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

log "Phase 01 completed successfully!"
log "Ready for Phase 02: Building Fil-C toolchain."

exit 0
