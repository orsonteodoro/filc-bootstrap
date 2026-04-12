#!/bin/bash
# =============================================================================
# Phase 01 - Prepare Base Environment (Improved git + cache handling)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 01] $*"
}

log "Starting Phase 01: Prepare Base Environment"

# Ensure we are in the correct location inside chroot
if [[ ! -d /root/filc-bootstrap ]]; then
    log "Copying bootstrap scripts into chroot..."
    mkdir -p /root/filc-bootstrap
    cp -a "$SCRIPT_DIR"/.. /root/filc-bootstrap/ 2>/dev/null || true
fi
cd /root/filc-bootstrap

# ====================== Distro Detection ======================
if [[ -f /etc/gentoo-release ]]; then
    DISTRO="gentoo"
    log "Detected Gentoo"
elif [[ -f /etc/alpine-release ]]; then
    DISTRO="alpine"
    log "Detected Alpine"
else
    DISTRO="unknown"
    log "WARNING: Unknown distribution"
fi

# ====================== DNS Check ======================
log "Verifying DNS resolution..."
if ! ping -c 1 -W 5 -q google.com >/dev/null 2>&1; then
    log "DNS failed. Applying fallback public DNS..."
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    chmod 644 /etc/resolv.conf
fi
log "DNS is working."

# ====================== Git Cache Setup ======================
mkdir -p "$GIT_CACHE_DIR"

# ====================== Clone / Update Fil-C ======================
log "Setting up Fil-C source at $FILC_SOURCE_DIR"

# Use absolute path inside chroot
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
    git checkout "$FILC_COMMIT" || log "WARNING: Commit not found, staying on branch"
fi

# Final verification with absolute path
if [[ ! -f "$ABS_FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "WARNING: build_all_fast_glibc.sh not found. Resetting to branch tip..."
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

# ====================== Install Dependencies ======================
log "Installing build dependencies..."

if [[ "$DISTRO" == "alpine" ]]; then
    apk add --no-cache \
        bash git curl wget ca-certificates \
        build-base clang clang-dev llvm llvm-dev llvm-static llvm-libs \
        cmake ninja \
        patchelf rsync tar \
        libxml2-dev curl-dev \
        openssl-dev zlib-dev \
        ncurses-dev readline-dev libedit-dev \
        libffi-dev python3-dev \
        bison flex \
        pkgconf \
        llvm-test-utils
    log "Verifying development headers..."
    ls -ld /usr/include/libxml2 2>/dev/null || log "WARNING: /usr/include/libxml2 not found"
    ls -ld /usr/include/curl 2>/dev/null || log "WARNING: /usr/include/curl not found"
    ls /usr/lib/libxml2* 2>/dev/null || log "WARNING: libxml2 library not found"
    ls /usr/lib/libcurl* 2>/dev/null || log "WARNING: libcurl library not found"
    log "Verifying critical LLVM static libraries..."
    for lib in LLVMDemangle LLVMTestingAnnotations LLVMCore LLVMSupport; do
        if ls /usr/lib/llvm*/lib/lib${lib}.a 2>/dev/null; then
            log "✅ lib${lib}.a found"
        else
            log "WARNING: lib${lib}.a missing"
        fi
    done
elif [[ "$DISTRO" == "gentoo" ]]; then
    emerge --sync --quiet || log "WARNING: emerge --sync failed"
    emerge -av --noreplace git clang llvm cmake ninja patchelf quilt rsync tar wget curl
fi

log "Build dependencies installed."

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
