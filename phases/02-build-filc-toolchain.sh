#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (Safe libxcrypt fix - no system symlink overwrite)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 02] $*"
}

log "Starting Phase 02: Building Fil-C Toolchain"

cd "$FILC_SOURCE_DIR" || {
    log "ERROR: Cannot cd to Fil-C source directory"
    exit 1
}

log "Current directory: $(pwd)"
log "Fil-C branch: $FILC_BRANCH"

# ====================== Force GCC for yolo-glibc ======================
export CC="gcc"
export CXX="g++"

log "Using CC=gcc  CXX=g++ (required for yolo-glibc)"

# ====================== Safe Fix for libxcrypt configure test ======================
log "Preparing safe environment for libxcrypt configure test..."

# Point to the actual yolo build output without overwriting system paths
YOLO_BUILD_DIR="/root/filc-bootstrap/sources/fil-c/pizlonated-yolo-glibc-build"

export LD_LIBRARY_PATH="${YOLO_BUILD_DIR}:${LD_LIBRARY_PATH:-}"
export PATH="/yolo/bin:${PATH}"

# Create a temporary symlink only for the configure test (in a safe location)
mkdir -p /tmp/yolo-test-lib
ln -sf "${YOLO_BUILD_DIR}/ld-linux-x86-64.so.2" /tmp/yolo-test-lib/ld-linux-x86-64.so.2 2>/dev/null || true
ln -sf "${YOLO_BUILD_DIR}/libc.so.6" /tmp/yolo-test-lib/libc.so.6 2>/dev/null || true

export LD_LIBRARY_PATH="/tmp/yolo-test-lib:${LD_LIBRARY_PATH}"

log "LD_LIBRARY_PATH set for conftest test using staging yolo build"

# ====================== Minimal patch for libpas ======================
log "Applying minimal patch to libpas..."

find . -path "*/libpas/*" -name "Makefile*" | while read -r makefile; do
    log "Patching $makefile"
    sed -i \
        -e "s|-march=[^ ]*|-march=${MARCH:-x86-64-v2}|g" \
        -e "s|-O[0-9s]*|-${OPT_LEVEL:-O2}|g" \
        "$makefile" || true
done

# ====================== Choose build script ======================
if [[ "$FILC_LIBC" == "musl" ]]; then
    BUILD_SCRIPT="build_all_fast_musl.sh"
else
    BUILD_SCRIPT="build_all_fast_glibc.sh"
fi

log "Starting build with $BUILD_SCRIPT ..."

chmod +x "./$BUILD_SCRIPT"

if ./"$BUILD_SCRIPT"; then
    log "✅ Fil-C build completed successfully."
else
    log "❌ Fil-C build failed."
    exit 1
fi

log "Phase 02 completed successfully!"

exit 0
