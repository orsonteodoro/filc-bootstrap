#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (Stronger integrated assembler + lld)
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

# ====================== Force Integrated Assembler + lld (Critical for CFI errors) ======================
if [[ -f /etc/alpine-release || -f /etc/debian_version ]]; then
    log "Forcing Clang integrated assembler and lld to fix CFI / pseudo-op errors..."

    export CC="clang -integrated-as"
    export CXX="clang++ -integrated-as"
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
    log "Fil-C build completed successfully."
else
    log "ERROR: Fil-C build failed. Check the log above for details."
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
