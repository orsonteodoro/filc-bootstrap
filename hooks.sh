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

# ====================== Debian Hooks ======================
debian_prepare_deps() {
    log "Debian: Installing dependencies..."
    apt-get update --allow-releaseinfo-change || true
    apt-get install -y --no-install-recommends \
        git curl wget ca-certificates \
        build-essential clang llvm llvm-dev libclang-dev lld \
        cmake ninja-build \
        autoconf automake libtool bison flex gawk texinfo \
        patchelf quilt rsync tar \
        libxml2-dev libcurl4-openssl-dev \
        libssl-dev zlib1g-dev \
        libncurses5-dev libreadline-dev libedit-dev \
        libffi-dev python3-dev \
        pkg-config
}

# ====================== Gentoo Hooks ======================
gentoo_prepare_deps() {
    log "Gentoo: Installing dependencies..."
    emerge --sync --quiet || log "WARNING: emerge --sync failed"
    emerge -av --noreplace \
        git clang llvm cmake ninja lld \
        autoconf automake libtool bison flex gawk texinfo \
        patchelf quilt rsync tar wget curl \
        sys-devel/gcc sys-libs/glibc
}

# Future hooks can be added here, e.g.:
# post_clone_hook() { ... }
