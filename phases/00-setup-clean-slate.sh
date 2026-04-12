#!/bin/bash
# =============================================================================
# Phase 00 - Setup Clean Slate (Improved Debian handling + safe --fresh)
# =============================================================================

set -euo pipefail

# Calculate host paths VERY EARLY
HOST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
HOST_BOOTSTRAP_PATH="$HOST_SCRIPT_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"

source "$HOST_SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 00] $*"
}

log "Starting Phase 00: Clean Slate Setup"

TARGET_ROOT="${TARGET_ROOT:-/mnt/filc-chroot}"
TEST_MODE=${TEST_MODE:-false}
TEST_DISTRO=${TEST_DISTRO:-"debian"}

ALPINE_MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.0-x86_64.tar.gz"

log "Target root: $TARGET_ROOT | Mode: $TEST_MODE ($TEST_DISTRO)"

# ====================== Safe Fresh Wipe ======================
if [[ "$FORCE_FRESH" == "true" ]]; then
    log "Force fresh enabled — preparing to wipe $TARGET_ROOT"

    if [[ "$TARGET_ROOT" == "/" || "$TARGET_ROOT" == "/home" || "$TARGET_ROOT" == "/root" || -z "$TARGET_ROOT" ]]; then
        log "ERROR: Refusing to wipe dangerous path"
        exit 1
    fi

    log "Unmounting filesystems under $TARGET_ROOT..."
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

# ====================== Debian (Improved for repeated runs) ======================
elif [[ "$TEST_MODE" == "true" && "$TEST_DISTRO" == "debian" ]]; then
    log "Setting up Debian test chroot using debootstrap..."

    if [[ -d "$TARGET_ROOT/usr" && "$FORCE_FRESH" != "true" ]]; then
        log "Existing Debian chroot detected. Skipping debootstrap (use --fresh to force recreate)."
    else
        if ! command -v debootstrap >/dev/null; then
            apt-get update && apt-get install -y debootstrap
        fi

        log "Running debootstrap (this may take a few minutes)..."
        debootstrap --variant=minbase stable "$TARGET_ROOT" http://deb.debian.org/debian
        log "Debian chroot created successfully."
    fi

# ====================== Gentoo ======================
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

# ====================== Reliable Script Copy + Consistency Check ======================
log "Copying filc-bootstrap scripts into chroot..."

mkdir -p "$TARGET_ROOT/root/filc-bootstrap"

# IMPORTANT: Only remove script files, protect source cache and checkpoints
log "Removing old script files (protecting sources, cache, and checkpoints)..."

# Safe removal: only delete *.sh files and known config files, leave sources/ and other dirs
find "$TARGET_ROOT/root/filc-bootstrap" -maxdepth 1 -type f \( -name "*.sh" -o -name "config.sh" -o -name "hooks.sh" \) -delete 2>/dev/null || true

# Now copy fresh scripts
log "Copying fresh scripts from host..."
cp -aT "$HOST_SCRIPT_DIR" "$TARGET_ROOT/root/filc-bootstrap" || {
    log "WARNING: cp -aT failed, trying fallback..."
    cp -a "$HOST_SCRIPT_DIR"/. "$TARGET_ROOT/root/filc-bootstrap/" 2>/dev/null || true
}

# ====================== Consistency Check ======================
log "Verifying script consistency between host and chroot..."

HOST_HASH=$(find "$HOST_SCRIPT_DIR" -maxdepth 1 -type f \( -name "*.sh" -o -name "config.sh" -o -name "hooks.sh" \) -exec sha256sum {} + 2>/dev/null | sort | sha256sum | awk '{print $1}')
CHROOT_HASH=$(find "$TARGET_ROOT/root/filc-bootstrap" -maxdepth 1 -type f \( -name "*.sh" -o -name "config.sh" -o -name "hooks.sh" \) 2>/dev/null | xargs sha256sum 2>/dev/null | sort | sha256sum | awk '{print $1}' || echo "failed")

if [[ "$HOST_HASH" == "$CHROOT_HASH" && "$CHROOT_HASH" != "failed" ]]; then
    log "✅ Script consistency check passed (host and chroot scripts match)"
else
    log "⚠️  WARNING: Script inconsistency detected between host and chroot"
    log "    Host hash   : ${HOST_HASH:0:16}..."
    log "    Chroot hash : ${CHROOT_HASH:0:16}..."
    log "    Consider running with --fresh if scripts are outdated."
fi

# Final safety check for critical files
if [[ ! -f "$TARGET_ROOT/root/filc-bootstrap/bootstrap.sh" || \
      ! -f "$TARGET_ROOT/root/filc-bootstrap/config.sh" || \
      ! -f "$TARGET_ROOT/root/filc-bootstrap/hooks.sh" ]]; then
    log "ERROR: One or more core scripts are missing in chroot after copy"
    ls -la "$TARGET_ROOT/root/filc-bootstrap/"
    exit 1
fi

log "✅ All core scripts copied successfully"

# Verify
if [[ -f "$TARGET_ROOT/root/filc-bootstrap/bootstrap.sh" ]]; then
    log "✅ bootstrap.sh copied successfully into chroot"
else
    log "ERROR: bootstrap.sh still not found after copy attempts"
    ls -la "$TARGET_ROOT/root/filc-bootstrap/"
    exit 1
fi

# Create dummy file
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
