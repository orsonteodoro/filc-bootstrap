#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (Aggressive fix for .lbe / .byt / CFI errors)
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
log "Target libc: $FILC_LIBC"

# ====================== Aggressive Fix for CFI / pseudo-op errors + ccache ======================
if [[ -f /etc/alpine-release || -f /etc/debian_version ]]; then
    log "Applying aggressive integrated assembler fix + ccache..."

    # Use ccache if available
    if command -v ccache >/dev/null; then
        CC_LAUNCHER="ccache "
        log "Using ccache for compilation"
    else
        CC_LAUNCHER=""
    fi

    export CC="${CC_LAUNCHER}clang -integrated-as -fno-asynchronous-unwind-tables -fno-exceptions"
    export CXX="${CC_LAUNCHER}clang++ -integrated-as -fno-asynchronous-unwind-tables -fno-exceptions"
    export ASM="clang -integrated-as"

    export CMAKE_ARGS="-DLLVM_USE_LINKER=lld \
                       -DCMAKE_ASM_COMPILER=clang \
                       -DCMAKE_ASM_FLAGS=-integrated-as \
                       -DLLVM_INCLUDE_TESTS=OFF \
                       -DLLVM_BUILD_TESTS=OFF \
                       -DLLVM_ENABLE_ASSERTIONS=OFF \
                       -DLLVM_ENABLE_Z3_SOLVER=OFF \
                       -DLLVM_ENABLE_OCAMLDOC=OFF \
                       -DLLVM_ENABLE_BINDINGS=OFF \
                       -DLLVM_TARGETS_TO_BUILD=X86 \
                       -DCMAKE_C_COMPILER_LAUNCHER=ccache \
                       -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
fi

if command -v ccache >/dev/null; then
    log "ccache statistics:"
    ccache -s | head -n 10
fi

# ====================== Choose build script ======================
if [[ "$FILC_LIBC" == "musl" ]]; then
    BUILD_SCRIPT="build_all_fast_musl.sh"
else
    export CC=gcc
    export CXX=g++
    BUILD_SCRIPT="build_all_fast_glibc.sh"
fi

if [[ ! -f "./$BUILD_SCRIPT" ]]; then
    log "ERROR: Build script $BUILD_SCRIPT not found!"
    ls -la
    exit 1
fi

# ====================== Build Fil-C ======================
log "Starting Fil-C build with $BUILD_SCRIPT ..."
log "This step can take 30 minutes to several hours depending on hardware."

chmod +x "./$BUILD_SCRIPT"

if ./"$BUILD_SCRIPT"; then
    log "✅ Fil-C build completed successfully."
else
    log "❌ Fil-C build failed. Check the log above for details."
    exit 1
fi

# ====================== Setup installation ======================
log "Setting up Fil-C installation..."

if [[ -d "/opt/fil" ]]; then
    log "Fil-C installed in /opt/fil"
    mkdir -p /usr/local/bin
    ln -sf /opt/fil/bin/filcc /usr/local/bin/filcc 2>/dev/null || true
    ln -sf /opt/fil/bin/fil++ /usr/local/bin/fil++ 2>/dev/null || true
fi

# Verify
if command -v filcc >/dev/null; then
    filcc --version | head -n 5
    log "filcc verification passed."
else
    log "WARNING: filcc not found in PATH"
fi

log "Phase 02 completed successfully!"
log "Fil-C compiler and runtime have been built."

echo ""
echo "Next step: Phase 03 (setup-dual-libc.sh)"

exit 0
