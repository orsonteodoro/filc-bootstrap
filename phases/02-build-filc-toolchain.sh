#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (Control march/O3 + patch libpas)
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

# ====================== Controlled Build Flags ======================
export MARCH="${MARCH:-x86-64-v2}"
export OPT_LEVEL="${OPT_LEVEL:-O2}"

log "Using -march=${MARCH} -${OPT_LEVEL}"

#export CFLAGS="-march=${MARCH} -${OPT_LEVEL} -pipe -fPIC -fno-strict-aliasing"
#export CXXFLAGS="${CFLAGS}"
#export LDFLAGS="-Wl,--as-needed"

# ====================== Patch libpas Makefiles to respect our flags ======================
log "Patching libpas Makefiles to respect our CFLAGS..."

find . -name "Makefile*" -path "*/libpas/*" | while read -r makefile; do
    log "Patching $makefile"
    sed -i \
        -e "s|-march=[^ ]*|-march=${MARCH}|g" \
        -e "s|-O[0-9s]*|-${OPT_LEVEL}|g" \
        "$makefile" || true
done

# Also patch any hardcoded flags in libxcrypt configure if needed
#if [[ -f "libxcrypt/configure" ]]; then
#    log "Patching libxcrypt configure for compatibility..."
#    sed -i 's|CFLAGS=.*|CFLAGS="${CFLAGS} ${MARCH_FLAG} ${OPT_FLAG}"|g' libxcrypt/configure || true
#fi

# ====================== Force integrated assembler ======================
if [[ -f /etc/alpine-release || -f /etc/debian_version ]]; then
    log "Forcing Clang integrated assembler and lld..."

    export CC="ccache clang -integrated-as"
    export CXX="ccache clang++ -integrated-as"
    export ASM="clang -integrated-as"

    export CMAKE_ARGS="-DLLVM_USE_LINKER=lld \
                       -DCMAKE_ASM_COMPILER=clang \
                       -DCMAKE_ASM_FLAGS=-integrated-as \
                       -DLLVM_INCLUDE_TESTS=OFF \
                       -DLLVM_BUILD_TESTS=OFF \
                       -DLLVM_ENABLE_ASSERTIONS=OFF"
fi

# ====================== Choose build script ======================
if [[ "$FILC_LIBC" == "musl" ]]; then
    BUILD_SCRIPT="build_all_fast_musl.sh"
else
    export CC=gcc
    export CC=g++
    BUILD_SCRIPT="build_all_fast_glibc.sh"
fi

if [[ ! -f "./$BUILD_SCRIPT" ]]; then
    log "ERROR: Build script $BUILD_SCRIPT not found!"
    exit 1
fi

# ====================== Build ======================
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
