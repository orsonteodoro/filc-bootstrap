#!/bin/bash
# =============================================================================
# Phase 00 - Setup Clean Slate (Safe --fresh with unmount)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 00] $*"
}

log "Starting Phase 00: Clean Slate Setup"

TARGET_ROOT="${TARGET_ROOT:-/mnt/filc-chroot}"
TEST_MODE=${TEST_MODE:-false}
TEST_DISTRO=${TEST_DISTRO:-"alpine"}

ALPINE_MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.0-x86_64.tar.gz"

log "Target root: $TARGET_ROOT | Mode: $TEST_MODE ($TEST_DISTRO)"

# ====================== Safety: Unmount before fresh wipe ======================
if [[ "$FORCE_FRESH" == "true" ]]; then
    log "Force fresh enabled — preparing to wipe $TARGET_ROOT"

    # Strong safety check
    if [[ "$TARGET_ROOT" == "/" || "$TARGET_ROOT" == "/home" || "$TARGET_ROOT" == "/root" ]]; then
        log "ERROR: Refusing to wipe dangerous path: $TARGET_ROOT"
        exit 1
    fi

    log "Unmounting any active mounts in $TARGET_ROOT..."
    for dir in proc sys dev run; do
        if mountpoint -q "$TARGET_ROOT/$dir"; then
            umount -R -l "$TARGET_ROOT/$dir" 2>/dev/null || true
        fi
    done

    log "Wiping target directory..."
    rm -rf "$TARGET_ROOT"/*
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
        bash git curl wget \
        build-base clang cmake ninja patchelf rsync tar

    log "✅ Alpine minirootfs ready with bash."

# ====================== Gentoo Stage 3 ======================
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

log "Chrooting into clean hermetic environment..."
exec chroot "$TARGET_ROOT" /bin/bash <<'CHROOT_EOF'
    set -euo pipefail
    cd /root/filc-bootstrap
    echo "=== Now running inside clean hermetic chroot ==="
    exec ./bootstrap.sh --skip-clean-slate "$@"
CHROOT_EOF

exit 0
