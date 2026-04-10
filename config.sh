#!/bin/bash
# =============================================================================
# filc-bootstrap - Configuration file
# =============================================================================

# ====================== Fil-C Settings ======================
export FILC_REPO="https://github.com/pizlonator/fil-c.git"
export FILC_BRANCH="deluge"
export FILC_COMMIT=""                          # Leave empty for latest, or pin a commit

export FILC_LIBC="glibc"                       # glibc (recommended) or musl
export FILC_PREFIX="/opt/fil"
export YOLO_PREFIX="/yolo"

# ====================== Build Settings ======================
export MAKEOPTS="-j$(nproc)"
export CFLAGS="-O2 -pipe -fPIC"
export CXXFLAGS="${CFLAGS}"

# Directories
export LOG_DIR="./logs"
export CHECKPOINT_DIR="./checkpoints"
export BACKUP_DIR="./backups"
export FILC_SOURCE_DIR="./sources/fil-c"

# ====================== Safety & Recovery ======================
export CREATE_SNAPSHOTS=true
export SNAPSHOT_PREFIX="filc-snapshot"

# ====================== Test / Binary Distro Support ======================
export TEST_MODE=${TEST_MODE:-false}           # true = fast test with Debian/Alpine
export TEST_DISTRO=${TEST_DISTRO:-"debian"}    # debian, alpine, or gentoo
export CHROOT_TYPE="auto"

# Gentoo-specific
export SKIP_GENTOO_BRIDGE=false

# Force flags (can be overridden via CLI)
export FORCE_FRESH=${FORCE_FRESH:-false}

# ====================== Logging Config ======================
log_config() {
    echo "=== filc-bootstrap Configuration ==="
    echo "Fil-C branch     : ${FILC_BRANCH}"
    echo "Fil-C libc       : ${FILC_LIBC}"
    echo "Fil-C prefix     : ${FILC_PREFIX}"
    echo "Test mode        : ${TEST_MODE} (${TEST_DISTRO})"
    echo "MAKEOPTS         : ${MAKEOPTS}"
    echo "====================================="
}

# log_config
