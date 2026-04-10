#!/bin/bash
# =============================================================================
# Phase 00 - Setup Clean Slate (Host-side)
# Supports: Gentoo stage 3 (default), Debian, and Alpine for testing
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 00] $*"
}

log "Starting Phase 00: Clean Slate / Chroot Setup"

# ====================== Configuration & Detection ======================
TARGET_ROOT="${TARGET_ROOT:-/mnt/filc-chroot}"
TEST_MODE=${TEST_MODE:-false}
TEST_DISTRO=${TEST_DISTRO:-"debian"}

log "Target root: $TARGET_ROOT"
log "Test mode: $TEST_MODE"

if [[ "$TEST_MODE" == "true" ]]; then
    log "Running in TEST MODE using $TEST_DISTRO"
fi

# ====================== Create target directory ======================
mkdir -p "$TARGET_ROOT"

if [[ "$FORCE_FRESH" == "true" ]]; then
    log "Force fresh enabled — wiping $TARGET_ROOT"
    rm -rf "$TARGET_ROOT"/*
fi

# ====================== Distro-specific Setup ======================
if [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "debian" ]]; then
    # ==================== Debian / Ubuntu Test Chroot ====================
    log "Creating Debian test chroot using debootstrap..."

    if ! command -v debootstrap >/dev/null; then
        log "Installing debootstrap..."
        apt-get update && apt-get install -y debootstrap
    fi

    debootstrap --variant=minbase stable "$TARGET_ROOT" http://deb.debian.org/debian || {
        log "ERROR: debootstrap failed"
        exit 1
    }

    # Copy DNS
    cp --dereference /etc/resolv.conf "$TARGET_ROOT/etc/resolv.conf" 2>/dev/null || true

elif [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "alpine" ]]; then
    # ==================== Alpine Test Chroot ====================
    log "Creating Alpine test chroot..."

    if ! command -v apk >/dev/null; then
        log "ERROR: apk not found. Please run this on Alpine host or install apk-static."
        exit 1
    fi

    # Simple Alpine chroot setup
    mkdir -p "$TARGET_ROOT"/{etc,lib,usr/bin}
    apk --root "$TARGET_ROOT" --initdb add --no-cache alpine-base bash git curl wget
    cp --dereference /etc/resolv.conf "$TARGET_ROOT/etc/resolv.conf" 2>/dev/null || true

else
    # ==================== Default: Gentoo Stage 3 ====================
    log "Creating clean Gentoo stage 3 (default mode)"

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

    log "Downloading Gentoo stage 3: $STAGE3_TARBALL"
    wget -c -O stage3.tar.xz "$STAGE3_URL"
    wget -c -O stage3.DIGESTS.asc "${STAGE3_URL}.DIGESTS.asc"

    log "Verifying checksums..."
    sha512sum -c --ignore-missing stage3.DIGESTS.asc || {
        log "ERROR: Checksum verification failed"
        exit 1
    }

    log "Unpacking stage 3 into $TARGET_ROOT..."
    tar xpvf stage3.tar.xz -C "$TARGET_ROOT" --xattrs-include='*.*' --numeric-owner
fi

# ====================== Common Chroot Mounts ======================
log "Setting up chroot mounts..."
mount --types proc /proc "$TARGET_ROOT/proc" 2>/dev/null || true
mount --rbind /sys "$TARGET_ROOT/sys" 2>/dev/null || true
mount --make-rslave "$TARGET_ROOT/sys" 2>/dev/null || true
mount --rbind /dev "$TARGET_ROOT/dev" 2>/dev/null || true
mount --make-rslave "$TARGET_ROOT/dev" 2>/dev/null || true
mount --bind /run "$TARGET_ROOT/run" 2>/dev/null || true
mount --make-slave "$TARGET_ROOT/run" 2>/dev/null || true

if [[ -d /sys/firmware/efi/efivars ]]; then
    mount --bind /sys/firmware/efi/efivars "$TARGET_ROOT/sys/firmware/efi/efivars" 2>/dev/null || true
fi

# ====================== Improved DNS Handoff ======================
log "Copying DNS resolver configuration..."
if [[ ! -f /etc/resolv.conf ]]; then
    log "Creating fallback resolv.conf on host..."
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
fi

cp --dereference /etc/resolv.conf "$TARGET_ROOT/etc/resolv.conf" 2>/dev/null || true
chmod 644 "$TARGET_ROOT/etc/resolv.conf" 2>/dev/null || true

log "DNS configuration copied."

# ====================== Copy bootstrap scripts into chroot ======================
log "Copying filc-bootstrap scripts into chroot..."
mkdir -p "$TARGET_ROOT/root/filc-bootstrap"
cp -a "$SCRIPT_DIR"/.. "$TARGET_ROOT/root/filc-bootstrap/" 2>/dev/null || true

# ====================== Chroot and continue ======================
log "Chrooting into $TARGET_ROOT and continuing bootstrap..."

exec chroot "$TARGET_ROOT" /bin/bash <<'CHROOT_EOF'
    set -euo pipefail
    cd /root/filc-bootstrap

    echo "=== Now running inside chroot ==="
    echo "Distro inside chroot: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME || echo 'Unknown')"

    # Continue with main bootstrap (skip Phase 00)
    exec ./bootstrap.sh --skip-clean-slate "$@"
CHROOT_EOF

exit 0
