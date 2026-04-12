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
        wget -c -O "$MINIROOTFS_FILE" "$MINIROOTFS_URL"
    fi

    log "Unpacking Alpine minirootfs..."
    tar -xzf "$MINIROOTFS_FILE" -C "$TARGET_ROOT"

    mkdir -p "$TARGET_ROOT/etc/apk"
    cat > "$TARGET_ROOT/etc/apk/repositories" <<EOF
http://dl-cdn.alpinelinux.org/alpine/v3.23/main
http://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

    apk --root "$TARGET_ROOT" --no-cache add bash git curl wget build-base clang cmake ninja patchelf rsync tar ccache
    log "✅ Alpine chroot setup completed."
}

# ====================== Gentoo Chroot Setup Hook ======================
gentoo_chroot_setup() {
    log "Gentoo: Setting up clean stage 3 chroot..."
    # (We can expand this later if needed)
    log "Gentoo chroot setup not fully implemented yet."
}
