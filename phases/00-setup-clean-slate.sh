#!/bin/bash
# =============================================================================
# Phase 00 - Setup Clean Slate (Simple reliable copy - final version)
# =============================================================================

set -euo pipefail

# Calculate host paths VERY EARLY, before any chroot or wipe
HOST_SCRIPT_DIR=$(dirname $(realpath "${BASH_SOURCE[0]}") )
HOST_BOOTSTRAP_PATH=$(realpath "$HOST_SCRIPT_DIR/..")

source "$HOST_SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 00] $*"
}

log "Starting Phase 00: Clean Slate Setup"

TARGET_ROOT="${TARGET_ROOT:-/mnt/filc-chroot}"
TEST_MODE=${TEST_MODE:-false}
TEST_DISTRO=${TEST_DISTRO:-"alpine"}

ALPINE_MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.0-x86_64.tar.gz"

log "Target root: $TARGET_ROOT | Mode: $TEST_MODE ($TEST_DISTRO)"
log "Host bootstrap path: $HOST_BOOTSTRAP_PATH"

# ====================== Gentle Fresh Wipe ======================
if [[ "$FORCE_FRESH" == "true" ]]; then
    log "Force fresh enabled — preparing to wipe $TARGET_ROOT"
    if [[ "$TARGET_ROOT" == "/" || "$TARGET_ROOT" == "/home" || "$TARGET_ROOT" == "/root" ]]; then
        log "ERROR: Refusing to wipe dangerous path"
        exit 1
    fi

    for dir in proc sys dev run; do
        if mountpoint -q "$TARGET_ROOT/$dir" 2>/dev/null; then
            umount "$TARGET_ROOT/$dir" 2>/dev/null || true
        fi
    done

    for dir in proc sys dev run; do
        if mountpoint -q "$TARGET_ROOT/$dir" 2>/dev/null; then
            umount -l "$TARGET_ROOT/$dir" 2>/dev/null || true
        fi
    done

    log "Wiping target directory..."
    rm -rf "$TARGET_ROOT"/* 2>/dev/null || true
fi

mkdir -p "$TARGET_ROOT"

# ====================== Alpine Minirootfs ======================
if [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "alpine" ]]; then
    log "Using Alpine minirootfs for clean hermetic test"

    MINIROOTFS_FILE="/tmp/alpine-minirootfs-3.23.0-x86_64.tar.gz"

    if [[ ! -f "$MINIROOTFS_FILE" ]]; then
        log "Downloading Alpine minirootfs..."
        wget -c -O "$MINIROOTFS_FILE" "$ALPINE_MINIROOTFS_URL"
    fi

    log "Unpacking Alpine minirootfs..."
    tar -xzf "$MINIROOTFS_FILE" -C "$TARGET_ROOT"

    mkdir -p "$TARGET_ROOT/etc/apk"
    cat > "$TARGET_ROOT/etc/apk/repositories" <<EOF
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

    log "Installing bash and build tools..."
    apk --root "$TARGET_ROOT" --no-cache add \
        bash git curl wget build-base clang cmake ninja patchelf rsync tar

else
    log "Setting up clean Gentoo stage 3..."
    STAGE3_MIRROR="https://distfiles.gentoo.org/releases/amd64/autobuilds"
    LATEST_FILE="latest-stage3-amd64.txt"
    STAGE3_PROFILE="stage3-amd64"

    cd /tmp
    wget -q -O latest-stage3.txt "${STAGE3_MIRROR}/${LATEST_FILE}"

    STAGE3_TARBALL=$(grep -E "${STAGE3_PROFILE}-.*\.tar\.xz$" latest-stage3.txt | awk '{print $1}' | tail -n1)
    if [[ -z "$STAGE3_TARBALL" ]]; then
        log "ERROR: Could not find Gentoo stage 3"
        exit 1
    fi

    STAGE3_URL="${STAGE3_MIRROR}/$(dirname "$(grep -E "${STAGE3_PROFILE}" latest-stage3.txt | awk '{print $1}' | tail -n1)")/${STAGE3_TARBALL}"

    wget -c -O stage3.tar.xz "$STAGE3_URL"
    wget -c -O stage3.DIGESTS.asc "${STAGE3_URL}.DIGESTS.asc"

    sha512sum -c --ignore-missing stage3.DIGESTS.asc || { log "Checksum failed"; exit 1; }

    log "Unpacking Gentoo stage 3..."
    tar xpvf stage3.tar.xz -C "$TARGET_ROOT" --xattrs-include='*.*' --numeric-owner
fi

# ====================== Reliable Copy using cp -aT ======================
log "Copying filc-bootstrap scripts into chroot using cp -aT..."

mkdir -p "$TARGET_ROOT/root/filc-bootstrap"

# Use cp -aT from the known good host path
log "Copying from: $HOST_BOOTSTRAP_PATH"

cp -aT "$HOST_BOOTSTRAP_PATH" "$TARGET_ROOT/root/filc-bootstrap" || {
    log "cp -aT failed, trying fallback copy..."
    cp -a "$HOST_BOOTSTRAP_PATH"/. "$TARGET_ROOT/root/filc-bootstrap/" 2>/dev/null || true
}

# Final verification
if [[ -f "$TARGET_ROOT/root/filc-bootstrap/bootstrap.sh" ]]; then
    log "✅ bootstrap.sh copied successfully into chroot"
else
    log "ERROR: bootstrap.sh still not found after copy attempts"
    ls -la "$TARGET_ROOT/root/filc-bootstrap/"
    exit 1
fi

# Create dummy file inside chroot
echo "Dummy test file created at $(date)" > "$TARGET_ROOT/root/filc-bootstrap/DUMMY_TEST_FILE.txt"
log "Dummy file created inside chroot"

# ====================== Chroot ======================
log "Chrooting into clean environment..."

exec chroot "$TARGET_ROOT" /bin/bash <<'CHROOT_EOF'
    set -euo pipefail

    cd /root/filc-bootstrap

    echo "=== Inside chroot diagnostics ==="
    echo "Current directory: $(pwd)"
    ls -la

    if [[ -f bootstrap.sh ]]; then
        echo "✅ bootstrap.sh FOUND"
    else
        echo "ERROR: bootstrap.sh NOT FOUND!"
        ls -la /root/filc-bootstrap/
        exit 1
    fi

    if [[ -f DUMMY_TEST_FILE.txt ]]; then
        echo "✅ Dummy file visible"
    fi

    echo "Starting main bootstrap..."
    exec ./bootstrap.sh --skip-clean-slate "$@"
CHROOT_EOF

exit 0
