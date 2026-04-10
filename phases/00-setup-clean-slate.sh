#!/bin/bash
# =============================================================================
# Phase 00 - Setup Clean Slate (with safety guard on rm -rf)
# Supports Gentoo, Debian, and Alpine reliably
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 00] $*"
}

log "Starting Phase 00: Clean Slate / Chroot Setup"

TARGET_ROOT="${TARGET_ROOT:-/mnt/filc-chroot}"
TEST_MODE=${TEST_MODE:-false}
TEST_DISTRO=${TEST_DISTRO:-"debian"}

log "Target root: $TARGET_ROOT | Test mode: $TEST_MODE ($TEST_DISTRO)"

# ====================== SAFETY CHECK BEFORE DESTRUCTIVE OPERATIONS ======================
if [[ "$FORCE_FRESH" == "true" ]]; then
    log "Force fresh mode enabled — about to wipe $TARGET_ROOT"

    # Strong safety guard
    if [[ -z "$TARGET_ROOT" || "$TARGET_ROOT" == "/" || "$TARGET_ROOT" == "/home" || "$TARGET_ROOT" == "/root" ]]; then
        log "ERROR: Refusing to wipe dangerous target: $TARGET_ROOT"
        log "TARGET_ROOT cannot be /, /home, /root, or empty."
        exit 1
    fi

    if [[ ! "$TARGET_ROOT" =~ ^/mnt/ && ! "$TARGET_ROOT" =~ ^/tmp/ && ! "$TARGET_ROOT" =~ ^/var/tmp/ ]]; then
        log "WARNING: TARGET_ROOT ($TARGET_ROOT) is not under /mnt/, /tmp/, or /var/tmp/."
        read -p "Are you sure you want to wipe this directory? (yes/NO): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log "Aborted by user."
            exit 1
        fi
    fi

    log "Wiping target directory: $TARGET_ROOT"
    rm -rf "$TARGET_ROOT"/*
fi

# ====================== Create target directory ======================
mkdir -p "$TARGET_ROOT"

# ====================== Alpine Test Mode (Fixed) ======================
if [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "alpine" ]]; then
    log "Creating Alpine test chroot..."

    APK_STATIC_APK="https://dl-cdn.alpinelinux.org/alpine/v3.23/main/x86_64/apk-tools-static-3.0.5-r0.apk"

    log "Downloading apk-tools-static..."
    wget -q -O /tmp/apk-tools-static.apk "$APK_STATIC_APK"

    if [[ ! -s /tmp/apk-tools-static.apk ]]; then
        log "ERROR: Failed to download apk-tools-static from $APK_STATIC_APK"
        exit 1
    fi

    log "Extracting apk.static..."
    tar -xzf /tmp/apk-tools-static.apk -C /tmp --wildcards 'sbin/apk.static' --strip-components=1 2>/dev/null || true

    if [[ ! -f /tmp/apk.static ]]; then
        log "ERROR: Could not extract apk.static"
        exit 1
    fi

    mv /tmp/apk.static /usr/bin/apk.static
    chmod +x /usr/bin/apk.static

    log "Bootstrapping minimal Alpine root..."
    /usr/bin/apk.static --root "$TARGET_ROOT" --initdb --no-cache --allow-untrusted add alpine-base bash

    mkdir -p "$TARGET_ROOT/etc/apk"
    cat > "$TARGET_ROOT/etc/apk/repositories" <<EOF
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

    log "Installing build tools..."
    apk --root "$TARGET_ROOT" --no-cache add \
        bash git curl wget build-base clang cmake ninja patchelf rsync tar

    log "Alpine chroot bootstrapped successfully."

# ====================== Debian Test Mode ======================
elif [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "debian" ]]; then
    log "Creating Debian test chroot using debootstrap..."
    if ! command -v debootstrap >/dev/null; then
        apt-get update && apt-get install -y debootstrap
    fi
    debootstrap --variant=minbase stable "$TARGET_ROOT" http://deb.debian.org/debian

# ====================== Gentoo Default ======================
else
    log "Creating clean Gentoo stage 3..."
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

# ====================== Common Setup ======================
log "Setting up mounts and DNS..."
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

log "Chrooting into environment..."
exec chroot "$TARGET_ROOT" /bin/bash <<'CHROOT_EOF'
    set -euo pipefail
    cd /root/filc-bootstrap
    echo "=== Now running inside chroot ==="
    exec ./bootstrap.sh --skip-clean-slate "$@"
CHROOT_EOF

exit 0
