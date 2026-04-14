#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (lld only, stable version)
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

# ====================== LLD Configuration ======================
export LDFLAGS="-fuse-ld=lld --thinlto-jobs=$(nproc) --no-gc-sections --icf=all"
export CMAKE_ARGS="-DLLVM_USE_LINKER=lld \
                   -DCMAKE_ASM_COMPILER=clang \
                   -DCMAKE_ASM_FLAGS=-integrated-as \
                   -DLLVM_INCLUDE_TESTS=OFF \
                   -DLLVM_BUILD_TESTS=OFF \
                   -DLLVM_ENABLE_ASSERTIONS=OFF"

log "LLD configured with thinlto-jobs=$(nproc)"

# ====================== Optional libpas patch ======================
if [[ -n "${MARCH:-}" || -n "${OPT_LEVEL:-}" ]]; then
    log "Patching libpas with -march=${MARCH:-x86-64-v2} -${OPT_LEVEL:-O2}"

    find . -path "*/libpas/*" -name "Makefile*" | while read -r makefile; do
        sed -i \
            -e "s|-march=[^ ]*|-march=${MARCH:-x86-64-v2}|g" \
            -e "s|-O[0-9s]*|-${OPT_LEVEL:-O2}|g" \
            "$makefile" || true
    done
fi

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
