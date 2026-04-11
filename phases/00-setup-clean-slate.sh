#!/bin/bash
# =============================================================================
# Phase 00 - Setup Clean Slate (Robust ISO mounting)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 00] $*"
}

log "Starting Phase 00: Clean Slate Setup (Robust ISO)"

TARGET_ROOT="${TARGET_ROOT:-/mnt/filc-chroot}"
TEST_MODE=${TEST_MODE:-false}
TEST_DISTRO=${TEST_DISTRO:-"alpine"}

# Reproducible ISO URLs
ALPINE_ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-standard-3.23.0-x86_64.iso"

log "Target root: $TARGET_ROOT | Mode: $TEST_MODE ($TEST_DISTRO)"

mkdir -p "$TARGET_ROOT"

if [[ "$FORCE_FRESH" == "true" ]]; then
    log "Force fresh enabled — wiping $TARGET_ROOT"
    if [[ "$TARGET_ROOT" == "/" || "$TARGET_ROOT" == "/home" || "$TARGET_ROOT" == "/root" ]]; then
        log "ERROR: Refusing to wipe dangerous path"
        exit 1
    fi
    rm -rf "$TARGET_ROOT"/*
fi

# ====================== Alpine ISO Setup ======================
if [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "alpine" ]]; then
    log "Setting up Alpine from ISO..."

    ISO_DIR="$HOME/qemu-alpine"
    ISO_FILE="$ISO_DIR/alpine-standard-3.23.0-x86_64.iso"

    mkdir -p "$ISO_DIR"

    if [[ ! -f "$ISO_FILE" ]]; then
        log "Downloading Alpine ISO for reproducibility..."
        wget -c -O "$ISO_FILE" "$ALPINE_ISO_URL"
    else
        log "Using existing ISO: $ISO_FILE"
    fi

    # Robust mount
    log "Mounting Alpine ISO..."
    mkdir -p /mnt/alpine-iso

    # Clean up any stale loop devices
    losetup -D 2>/dev/null || true

    if ! mount -o loop,ro "$ISO_FILE" /mnt/alpine-iso 2>/dev/null; then
        log "ERROR: Failed to mount ISO. Trying alternative method..."
        # Fallback: use losetup manually
        LOOPDEV=$(losetup -fP --show "$ISO_FILE")
        if [[ -n "$LOOPDEV" ]]; then
            mount -o ro "${LOOPDEV}p1" /mnt/alpine-iso 2>/dev/null || \
            mount -o ro "$LOOPDEV" /mnt/alpine-iso || {
                log "ERROR: All mount attempts failed"
                exit 1
            }
        else
            log "ERROR: Could not set up loop device"
            exit 1
        fi
    fi

    log "ISO mounted successfully. Copying live filesystem..."
    rsync -a --exclude=/dev --exclude=/proc --exclude=/sys --exclude=/run \
        /mnt/alpine-iso/ "$TARGET_ROOT/" || true

    umount /mnt/alpine-iso 2>/dev/null || true
    rmdir /mnt/alpine-iso 2>/dev/null || true

# ====================== Debian (debootstrap fallback) ======================
elif [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "debian" ]]; then
    log "Creating Debian clean slate using debootstrap..."
    if ! command -v debootstrap >/dev/null; then
        apt-get update && apt-get install -y debootstrap
    fi
    debootstrap --variant=minbase stable "$TARGET_ROOT" http://deb.debian.org/debian

# ====================== Gentoo Stage 3 ======================
else
    log "Creating clean Gentoo stage 3..."
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

# ====================== Common Setup ======================
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

log "Chrooting into clean environment..."
exec chroot "$TARGET_ROOT" /bin/bash <<'CHROOT_EOF'
    set -euo pipefail
    cd /root/filc-bootstrap
    echo "=== Now running inside clean chroot ==="
    exec ./bootstrap.sh --skip-clean-slate "$@"
CHROOT_EOF

exit 0
