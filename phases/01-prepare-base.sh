#!/bin/bash
# =============================================================================
# Phase 01 - Prepare Base Environment (Inside Chroot)
# Pre-LC: Install dependencies and prepare the clean stage 3 environment
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 01] $*"
}

log "Starting Phase 01: Prepare Base Environment (inside clean chroot)"

# Ensure we are running from the correct location inside chroot
if [[ ! -d /root/filc-bootstrap ]]; then
    log "Creating /root/filc-bootstrap and copying scripts..."
    mkdir -p /root/filc-bootstrap
    cp -a "$SCRIPT_DIR"/.. /root/filc-bootstrap/ 2>/dev/null || true
    cd /root/filc-bootstrap
else
    cd /root/filc-bootstrap
fi

# ====================== DNS Verification & Fallback ======================
log "Verifying DNS resolution inside the chroot..."

if ! ping -c 1 -W 5 -q google.com >/dev/null 2>&1; then
    log "DNS resolution failed. Applying fallback public DNS servers..."
    cat > /etc/resolv.conf <<'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
EOF
    chmod 644 /etc/resolv.conf

    # Test again after fallback
    if ping -c 1 -W 5 -q google.com >/dev/null 2>&1; then
        log "Fallback DNS applied successfully."
    else
        log "WARNING: DNS still not working. Internet access may be limited."
    fi
else
    log "DNS resolution is working correctly."
fi

# ====================== Update Portage and sync ======================
log "Updating Portage tree..."
emerge --sync --quiet || {
    log "WARNING: emerge --sync failed (using cached tree if available)."
}

# ====================== Install Build Dependencies ======================
log "Installing required build dependencies..."

emerge -av --noreplace \
    git \
    clang \
    llvm \
    cmake \
    ninja \
    autoconf \
    automake \
    libtool \
    bison \
    flex \
    gawk \
    texinfo \
    patchelf \
    quilt \
    rsync \
    tar \
    wget \
    curl \
    sys-devel/gcc \
    sys-libs/glibc

log "Core build dependencies installed."

# ====================== Clone / Update Fil-C Repository ======================
log "Setting up Fil-C source at $FILC_SOURCE_DIR"

if [[ -d "$FILC_SOURCE_DIR/.git" ]]; then
    log "Fil-C repository exists. Updating..."
    cd "$FILC_SOURCE_DIR"
    git fetch origin
    git checkout "$FILC_BRANCH"
    if [[ -n "$FILC_COMMIT" ]]; then
        git checkout "$FILC_COMMIT"
    fi
    git pull --ff-only || true
    log "Fil-C repository updated."
else
    log "Cloning Fil-C repository (branch: $FILC_BRANCH)..."
    mkdir -p "$(dirname "$FILC_SOURCE_DIR")"
    git clone --branch "$FILC_BRANCH" "$FILC_REPO" "$FILC_SOURCE_DIR"
    cd "$FILC_SOURCE_DIR"
    if [[ -n "$FILC_COMMIT" ]]; then
        git checkout "$FILC_COMMIT"
        log "Pinned to commit: $FILC_COMMIT"
    fi
fi

# Safety check for Fil-C build scripts
if [[ ! -f "$FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "ERROR: Fil-C build scripts not found after clone!"
    exit 1
fi

log "Fil-C source is ready at $FILC_SOURCE_DIR"

# ====================== Create Backup Snapshot ======================
if [[ "$CREATE_SNAPSHOTS" == "true" ]]; then
    SNAPSHOT_NAME="${SNAPSHOT_PREFIX}-post-phase01-$(date '+%Y%m%d-%H%M%S').tar.gz"
    log "Creating post-phase01 snapshot: $BACKUP_DIR/$SNAPSHOT_NAME"
    mkdir -p "$BACKUP_DIR"
    tar -czf "$BACKUP_DIR/$SNAPSHOT_NAME" \
        --exclude=/proc \
        --exclude=/sys \
        --exclude=/dev \
        --exclude=/run \
        --exclude=/tmp \
        /bin /sbin /usr/bin /usr/sbin /lib /lib64 /usr/lib /usr/lib64 /etc 2>/dev/null || true
    log "Snapshot created."
fi

# ====================== Final Verification ======================
log "Running final checks..."

command -v git >/dev/null || { log "ERROR: git not found"; exit 1; }
command -v clang >/dev/null || { log "ERROR: clang not found"; exit 1; }
command -v patchelf >/dev/null || { log "WARNING: patchelf is missing (will be needed in LC phase)"; }

log "Phase 01 completed successfully!"
log "Clean Gentoo stage 3 is prepared and ready for Phase 02 (Build Fil-C Toolchain)."

echo ""
echo "Next: Building Fil-C compiler and runtime (Phase 02)"

exit 0
