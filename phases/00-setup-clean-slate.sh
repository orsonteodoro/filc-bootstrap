#!/bin/bash
# =============================================================================
# Phase 00 - Setup Clean Slate (Option 1: Alpine minirootfs + Gentoo stage 3)
# Purpose: Create uncontaminated, hermetic, reproducible environment
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 00] $*"
}

log "Starting Phase 00: Clean Hermetic Slate Setup (Minirootfs)"

TARGET_ROOT="${TARGET_ROOT:-/mnt/filc-chroot}"
TEST_MODE=${TEST_MODE:-false}
TEST_DISTRO=${TEST_DISTRO:-"alpine"}

# Reproducible URLs
ALPINE_MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.0-x86_64.tar.gz"

log "Target root: $TARGET_ROOT | Mode: $TEST_MODE ($TEST_DISTRO)"

# Safety check
if [[ "$FORCE_FRESH" == "true" ]]; then
    log "Force fresh enabled — wiping $TARGET_ROOT"
    if [[ "$TARGET_ROOT" == "/" || "$TARGET_ROOT" == "/home" || "$TARGET_ROOT" == "/root" ]]; then
        log "ERROR: Refusing to wipe dangerous path: $TARGET_ROOT"
        exit 1
    fi
    rm -rf "$TARGET_ROOT"/*
fi

mkdir -p "$TARGET_ROOT"

# ====================== Alpine Minirootfs (Clean & Hermetic) ======================
if [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "alpine" ]]; then
    log "Using Alpine minirootfs for clean hermetic test environment"

    MINIROOTFS_FILE="/tmp/alpine-minirootfs-3.23.0-x86_64.tar.gz"

    if [[ ! -f "$MINIROOTFS_FILE" ]]; then
        log "Downloading Alpine minirootfs for reproducibility..."
        wget -c -O "$MINIROOTFS_FILE" "$ALPINE_MINIROOTFS_URL"
    else
        log "Using cached minirootfs: $MINIROOTFS_FILE"
    fi

    log "Unpacking clean Alpine minirootfs into $TARGET_ROOT..."
    tar -xzf "$MINIROOTFS_FILE" -C "$TARGET_ROOT"

    # Setup APK repositories
    mkdir -p "$TARGET_ROOT/etc/apk"
    cat > "$TARGET_ROOT/etc/apk/repositories" <<EOF
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

    log "✅ Alpine minirootfs unpacked successfully (hermetic base ready)."

# ====================== Gentoo Stage 3 (for real builds) ======================
else
    log "Setting up clean Gentoo stage 3 (hermetic full build)"
    STAGE3_MIRROR="https://distfiles.gentoo.org/releases/amd64/autobuilds"
    LATEST_FILE="latest-stage3-amd64.txt"
    STAGE3_PROFILE="stage3-amd64"

    cd /tmp
    wget -q -O latest-stage3.txt "${STAGE3_MIRROR}/${LATEST_FILE}"

    STAGE3_TARBALL=$(grep -E "${STAGE3_PROFILE}-.*\.tar\.xz$" latest-stage3.txt | awk '{print $1}' | tail -n1)
    if [[ -z "$STAGE3_TARBALL" ]]; then
        log "ERROR: Could not find Gentoo stage 3 tarball"
        exit 1
    fi

    STAGE3_URL="${STAGE3_MIRROR}/$(dirname "$(grep -E "${STAGE3_PROFILE}" latest-stage3.txt | awk '{print $1}' | tail -n1)")/${STAGE3_TARBALL}"

    wget -c -O stage3.tar.xz "$STAGE3_URL"
    wget -c -O stage3.DIGESTS.asc "${STAGE3_URL}.DIGESTS.asc"

    sha512sum -c --ignore-missing stage3.DIGESTS.asc || { log "Checksum failed"; exit 1; }

    log "Unpacking Gentoo stage 3..."
    tar xpvf stage3.tar.xz -C "$TARGET_ROOT" --xattrs-include='*.*' --numeric-owner
fi

# ====================== Common Chroot Setup ======================
log "Setting up chroot mounts and DNS..."

mount --types proc /proc "$TARGET_ROOT/proc" 2>/dev/null || true
mount --rbind /sys "$TARGET_ROOT/sys" 2>/dev/null || true
mount --make-rslave "$TARGET_ROOT/sys" 2>/dev/null || true
mount --rbind /dev "$TARGET_ROOT/dev" 2>/dev/null || true
mount --make-rslave "$TARGET_ROOT/dev" 2>/dev/null || true
mount --bind /run "$TARGET_ROOT/run" 2>/dev/null || true

cp --dereference /etc/resolv.conf "$TARGET_ROOT/etc/resolv.conf" 2>/dev/null || true
chmod 644 "$TARGET_ROOT/etc/resolv.conf" 2>/dev/null || true

log "Copying filc-bootstrap scripts into chroot..."
mkdir -p "$TARGET_ROOT/root/filc-bootstrap"
cp -a "$SCRIPT_DIR"/.. "$TARGET_ROOT/root/filc-bootstrap/" 2>/dev/null || true

log "Chrooting into clean hermetic environment..."
exec chroot "$TARGET_ROOT" /bin/bash <<'CHROOT_EOF'
    set -euo pipefail
    cd /root/filc-bootstrap
    echo "=== Now running inside clean hermetic chroot ==="
    exec ./bootstrap.sh --skip-clean-slate "$@"
CHROOT_EOF

exit 0
