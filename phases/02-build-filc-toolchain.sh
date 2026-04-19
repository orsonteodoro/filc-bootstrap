#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (with globals patch + symbol replacement)
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

# ====================== 1. Apply globals patch ======================
log "Applying globals patch: patches/fil-c-0.678-globals.patch"

if [[ -f "$SCRIPT_DIR/patches/fil-c-0.678-globals.patch" ]]; then
    patch -Np1 -i "$SCRIPT_DIR/patches/fil-c-0.678-globals.patch" || {
        log "WARNING: Patch applied with some offsets or already applied"
    }
else
    log "ERROR: globals patch not found at $SCRIPT_DIR/patches/fil-c-0.678-globals.patch"
    exit 1
fi

# ====================== 2. Source globals ======================
log "Sourcing globals.sh"

# Source the globals (use bash version if available, fallback to sh)
if [[ -f "globals.sh" ]]; then
    . "./globals.sh"
else
    log "ERROR: globals.sh not found!"
    exit 1
fi

log "Globals loaded: YOLO_PREFIX=${YOLO_PREFIX}, FIL_PREFIX=${FIL_PREFIX}, LIBDIR=${LIBDIR}"

# ====================== 3. Run replace_symbols.sh ======================
log "Running replace_symbols.sh to expand @VAR@ placeholders..."

if [[ -f "replace_symbols.sh" ]]; then
    chmod +x "./replace_symbols.sh"
    ./replace_symbols.sh || {
        log "WARNING: replace_symbols.sh returned non-zero (continuing)"
    }
else
    log "WARNING: replace_symbols.sh not found - skipping symbol replacement"
fi

# ====================== 4. Safe environment for glibc configure ======================
log "Setting up safe environment for glibc configure tests..."

YOLO_BUILD_DIR="${FILC_SOURCE_DIR}/pizlonated-yolo-glibc-build"

mkdir -p /tmp/yolo-test-lib
ln -sf "${YOLO_BUILD_DIR}/ld-linux-x86-64.so.2" /tmp/yolo-test-lib/ld-linux-x86-64.so.2 2>/dev/null || true
ln -sf "${YOLO_BUILD_DIR}/libc.so.6" /tmp/yolo-test-lib/libc.so.6 2>/dev/null || true

# Clean LD_LIBRARY_PATH - remove '.' to satisfy glibc check
CLEAN_LD_PATH="/tmp/yolo-test-lib:${YOLO_BUILD_DIR}"
if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
    CLEAN_LD_PATH="${CLEAN_LD_PATH}:$(echo "${LD_LIBRARY_PATH}" | sed 's|\.:||g; s|::|:|g; s|^:||; s|:$||')"
fi
export LD_LIBRARY_PATH="${CLEAN_LD_PATH}"

export PATH="${YOLO_PREFIX}/bin:${PATH}"

log "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"

# ====================== 5. Force GCC for yolo-glibc ======================
export CC="gcc"
export CXX="g++"
export CC_FOR_BUILD="gcc"
export CXX_FOR_BUILD="g++"

log "Using CC=gcc / CXX=g++"

# ====================== Clang + integrated-as build configuration ======================
export CMAKE_ARGS="-DLLVM_USE_LINKER=lld \
                   -DCMAKE_ASM_COMPILER=clang \
                   -DCMAKE_ASM_FLAGS=-integrated-as \
                   -DLLVM_INCLUDE_TESTS=OFF \
                   -DLLVM_BUILD_TESTS=OFF \
                   -DLLVM_ENABLE_ASSERTIONS=OFF"

# ====================== 6. Choose and run build script ======================
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
