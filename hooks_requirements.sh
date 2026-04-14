#!/bin/bash
# =============================================================================
# hooks.sh - Distro-specific hooks (like requirements.txt)
# Place all prepare_deps, post_clone, etc. hooks here
# =============================================================================

# ====================== Alpine Hooks ======================
alpine_prepare_deps() {
    log "Alpine: Installing dependencies..."
    apk update
    apk add --no-cache \
        bash git curl wget ca-certificates \
        build-base clang clang-dev llvm llvm-dev llvm-static llvm-libs \
        cmake ninja \
        patchelf rsync tar \
        libxml2-dev curl-dev \
        openssl-dev zlib-dev \
        ncurses-dev readline-dev libedit-dev \
        libffi-dev python3-dev \
        bison flex \
        pkgconf
}

# ====================== Debian Requirements Hook ======================
debian_prepare_deps() {
    log "Debian: Installing dependencies + mold + tools for yolo-glibc..."

    # Force a clean package list update
    apt-get update --allow-releaseinfo-change -qq || {
        log "WARNING: apt-get update failed, retrying with --fix-missing"
        apt-get update --allow-releaseinfo-change --fix-missing || true
    }

    apt-get install -y --no-install-recommends \
        git curl wget ca-certificates \
        build-essential \
        gcc g++ \
        ruby \
        libc6-dev \
        linux-libc-dev \
        clang llvm llvm-dev libclang-dev lld \
        mold \                          # ← Added: preferred fast linker
        cmake ninja-build \
        ccache \
        autoconf automake libtool bison flex gawk texinfo \
        patchelf quilt rsync tar \
        libxml2-dev libcurl4-openssl-dev \
        libssl-dev zlib1g-dev \
        libncurses5-dev libreadline-dev libedit-dev \
        libffi-dev python3-dev \
        pkg-config || {
            log "ERROR: Some packages failed to install. Retrying critical ones..."
            apt-get install -y --no-install-recommends --fix-missing \
                ruby libc6-dev linux-libc-dev build-essential mold || die "Critical packages still missing"
        }

    # Configure ccache (optional, but useful for rebuilds)
    if command -v ccache >/dev/null; then
        ccache --max-size=8G
        ccache -z
        log "✅ ccache enabled with 8 GiB max size"
    fi

    log "GCC version: $(gcc --version | head -n1)"
    log "Mold version: $(mold --version 2>/dev/null || echo 'not found')"
    log "Ruby version: $(ruby --version 2>/dev/null || echo 'not found')"
    log "stddef.h location: $(find /usr -name stddef.h 2>/dev/null | head -n 3 || echo 'not found')"

    log "✅ Debian dependencies installed successfully."
}

# ====================== Gentoo Requirements Hook ======================
gentoo_prepare_deps() {
    log "Gentoo: Installing dependencies + ccache..."

    # Sync portage if needed
    emerge --sync --quiet || log "WARNING: emerge --sync failed (continuing anyway)"

    emerge -av --noreplace \
        git \
        clang \
        llvm \
        cmake \
        ninja \
        ccache \
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
        sys-libs/glibc \
        dev-libs/libxml2 \
        net-misc/curl

    # Configure ccache for Gentoo
    if command -v ccache >/dev/null; then
        log "Configuring ccache for Gentoo..."
        ccache --max-size=8G
        ccache -z
        # Enable ccache in Portage
        echo 'FEATURES="ccache"' >> /etc/portage/make.conf 2>/dev/null || true
        log "✅ ccache enabled with 8 GiB max size and Portage integration"
    fi

    log "Gentoo dependencies installed."
}

# Future hooks can be added here, e.g.:
# post_clone_hook() { ... }
