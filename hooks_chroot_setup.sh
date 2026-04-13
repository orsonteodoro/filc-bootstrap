#!/bin/bash
# =============================================================================
# hooks_chroot_setup.sh - Chroot setup hooks for different distros
# =============================================================================

# ====================== Debian Chroot Setup Hook ======================
debian_chroot_setup() {
    log "Debian: Setting up clean chroot with debootstrap..."

    if [[ -d "$TARGET_ROOT/usr" && "$FORCE_FRESH" != "true" ]]; then
        log "Existing Debian chroot detected. Skipping debootstrap."
        return 0
    fi

    if ! command -v debootstrap >/dev/null; then
        apt-get update && apt-get install -y debootstrap
    fi

    log "Running debootstrap (this may take a few minutes)..."
    debootstrap --variant=minbase stable "$TARGET_ROOT" http://deb.debian.org/debian
    log "✅ Debian chroot created successfully."
}

# ====================== Alpine Chroot Setup Hook ======================
alpine_chroot_setup() {
    log "Alpine: Setting up clean chroot with minirootfs..."

    MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-minirootfs-3.23.0-x86_64.tar.gz"
    MINIROOTFS_FILE="/tmp/alpine-minirootfs-3.23.0-x86_64.tar.gz"

    if [[ ! -f "$MINIROOTFS_FILE" ]]; then
        log "Downloading Alpine minirootfs..."
        wget -c -O "$MINIROOTFS_FILE" "$MINIROOTFS_URL"
    fi

    log "Unpacking Alpine minirootfs..."
    tar -xzf "$MINIROOTFS_FILE" -C "$TARGET_ROOT"

    mkdir -p "$TARGET_ROOT/etc/apk"
    cat > "$TARGET_ROOT/etc/apk/repositories" <<EOF
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

    log "Installing base packages into Alpine chroot..."
    apk --root "$TARGET_ROOT" --no-cache add \
        bash git curl wget ca-certificates \
        build-base clang cmake ninja ccache patchelf rsync tar

    log "✅ Alpine chroot setup completed."
}

# ====================== Gentoo Chroot Setup Hook ======================
gentoo_chroot_setup() {
    log "Gentoo: Setting up clean stage 3 chroot..."

    STAGE3_MIRROR="https://distfiles.gentoo.org/releases/amd64/autobuilds"
    LATEST_FILE="latest-stage3-amd64.txt"
    STAGE3_PROFILE="stage3-amd64"

    cd /tmp

    log "Downloading latest Gentoo stage 3 index..."
    wget -q -O latest-stage3.txt "${STAGE3_MIRROR}/${LATEST_FILE}"

    STAGE3_TARBALL=$(grep -E "${STAGE3_PROFILE}-.*\.tar\.xz$" latest-stage3.txt | awk '{print $1}' | tail -n1)
    if [[ -z "$STAGE3_TARBALL" ]]; then
        log "ERROR: Could not find Gentoo stage 3 tarball"
        exit 1
    fi

    STAGE3_URL="${STAGE3_MIRROR}/$(dirname "$(grep -E "${STAGE3_PROFILE}" latest-stage3.txt | awk '{print $1}' | tail -n1)")/${STAGE3_TARBALL}"

    log "Downloading Gentoo stage 3: ${STAGE3_TARBALL}"
    wget -c -O stage3.tar.xz "$STAGE3_URL"
    wget -c -O stage3.DIGESTS.asc "${STAGE3_URL}.DIGESTS.asc"

    log "Verifying checksum..."
    sha512sum -c --ignore-missing stage3.DIGESTS.asc || {
        log "ERROR: Checksum verification failed"
        exit 1
    }

    log "Unpacking Gentoo stage 3 into $TARGET_ROOT..."
    tar xpvf stage3.tar.xz -C "$TARGET_ROOT" --xattrs-include='*.*' --numeric-owner

    log "✅ Gentoo stage 3 chroot setup completed."
    log "   Stage 3 tarball: ${STAGE3_TARBALL}"
}
