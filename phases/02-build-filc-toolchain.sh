#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (CC=gcc + ccache wrapper)
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

# ====================== Setup CC/CXX with ccache if available ======================
if command -v ccache >/dev/null; then
    log "ccache detected. Wrapping gcc/g++ with ccache."
    GCC_WRAPPER="ccache gcc"
    GXX_WRAPPER="ccache g++"
else
    log "ccache not found. Using plain gcc/g++."
    GCC_WRAPPER="gcc"
    GXX_WRAPPER="g++"
fi

export CC="${GCC_WRAPPER}"
export CXX="${GXX_WRAPPER}"

log "Using CC=${CC}  CXX=${CXX}"

# ====================== Patch libpas for march and optimization ======================
log "Patching libpas Makefiles..."

find . -path "*/libpas/*" -name "Makefile*" | while read -r makefile; do
    log "Patching $makefile"
    sed -i \
        -e "s|-march=[^ ]*|-march=${MARCH:-x86-64-v2}|g" \
        -e "s|-O[0-9s]*|-${OPT_LEVEL:-O2}|g" \
        "$makefile" || true
done

log "libpas patched with -march=${MARCH:-x86-64-v2} -${OPT_LEVEL:-O2}"

# ====================== Choose and run build script ======================
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
