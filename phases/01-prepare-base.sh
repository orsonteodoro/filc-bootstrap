#!/bin/bash
# =============================================================================
# Phase 01 - Prepare Base Environment (Distro-aware)
# Works inside Alpine minirootfs or Gentoo stage 3
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 01] $*"
}

log "Starting Phase 01: Prepare Base Environment"

# Ensure we are in the chroot and scripts are in place
if [[ ! -d /root/filc-bootstrap ]]; then
    log "Copying bootstrap scripts into chroot..."
    mkdir -p /root/filc-bootstrap
    cp -a "$SCRIPT_DIR"/.. /root/filc-bootstrap/ 2>/dev/null || true
fi
cd /root/filc-bootstrap

# ====================== Detect Distro ======================
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

# ====================== Install Dependencies (Distro-specific) ======================
log "Installing build dependencies..."

if [[ "$DISTRO" == "alpine" ]]; then
    log "Alpine detected - installing packages with apk..."
    apk add --no-cache \
        bash git curl wget \
        build-base clang clang-dev llvm llvm-dev \
        cmake ninja \
        patchelf rsync tar \
        ca-certificates

elif [[ "$DISTRO" == "gentoo" ]]; then
    log "Gentoo detected - running emerge --sync and installing packages..."
    emerge --sync --quiet || log "WARNING: emerge --sync failed (continuing with cache)"

    emerge -av --noreplace \
        git clang llvm cmake ninja \
        autoconf automake libtool bison flex gawk texinfo \
        patchelf quilt rsync tar wget curl \
        sys-devel/gcc sys-libs/glibc

elif [[ "$DISTRO" == "debian" ]]; then
    log "Debian detected - installing with apt..."
    apt-get update
    apt-get install -y \
        git clang llvm cmake ninja-build \
        autoconf automake libtool bison flex gawk texinfo \
        patchelf quilt rsync tar wget curl build-essential
else
    log "WARNING: Unknown distro. Trying to install common tools..."
    command -v apk && apk add --no-cache git clang cmake ninja build-base patchelf || true
    command -v apt-get && apt-get update && apt-get install -y git clang cmake ninja-build build-essential || true
fi

log "Build dependencies installed."

# ====================== Clone / Update Fil-C ======================
log "Setting up Fil-C source at $FILC_SOURCE_DIR"

if [[ -d "$FILC_SOURCE_DIR/.git" ]]; then
    log "Updating existing Fil-C repository..."
    cd "$FILC_SOURCE_DIR"
    git fetch origin
    git checkout "$FILC_BRANCH"
    if [[ -n "$FILC_COMMIT" ]]; then
        git checkout "$FILC_COMMIT"
    fi
    git pull --ff-only || true
else
    log "Cloning Fil-C repository..."
    mkdir -p "$(dirname "$FILC_SOURCE_DIR")"
    git clone --branch "$FILC_BRANCH" "$FILC_REPO" "$FILC_SOURCE_DIR"
    cd "$FILC_SOURCE_DIR"
    if [[ -n "$FILC_COMMIT" ]]; then
        git checkout "$FILC_COMMIT"
    fi
fi

if [[ ! -f "$FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "ERROR: Fil-C build scripts not found!"
    exit 1
fi

log "Fil-C source ready."

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
