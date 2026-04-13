#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (Correct ccache wrapper + CC=gcc)
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

# ====================== Setup ccache wrapper correctly ======================
if command -v ccache >/dev/null; then
    log "ccache detected. Using ccache gcc / ccache g++ wrapper."
    CC_WRAPPER="ccache gcc"
    CXX_WRAPPER="ccache g++"
else
    log "ccache not found. Using plain gcc/g++."
    CC_WRAPPER="gcc"
    CXX_WRAPPER="g++"
fi

export CC="${CC_WRAPPER}"
export CXX="${CXX_WRAPPER}"

log "Final CC=${CC}   CXX=${CXX}"

# ====================== Patch libpas Makefiles ======================
log "Patching libpas Makefiles to control march and optimization..."

find . -path "*/libpas/*" -name "Makefile*" | while read -r makefile; do
    log "Patching $makefile"
    sed -i \
        -e "s|-march=[^ ]*|-march=${MARCH:-x86-64-v2}|g" \
        -e "s|-O[0-9s]*|-${OPT_LEVEL:-O2}|g" \
        "$makefile" || true
done

log "libpas patched with -march=${MARCH:-x86-64-v2} -${OPT_LEVEL:-O2}"

# ====================== Choose build script ======================
if [[ "$FILC_LIBC" == "musl" ]]; then
    BUILD_SCRIPT="build_all_fast_musl.sh"
else
    BUILD_SCRIPT="build_all_fast_glibc.sh"
fi

log "Starting build with $BUILD_SCRIPT ..."

chmod +x "./$BUILD_SCRIPT"

# Run the build with the correct wrapper
if ./"$BUILD_SCRIPT"; then
    log "✅ Fil-C build completed successfully."
else
    log "❌ Fil-C build failed."
    exit 1
fi

log "Phase 02 completed successfully!"

exit 0
