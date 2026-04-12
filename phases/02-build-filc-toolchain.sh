#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain (Fixed library detection for Alpine)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 02] $*"
}

log "Starting Phase 02: Building Fil-C Toolchain"

cd "$FILC_SOURCE_DIR" || {
    log "ERROR: Cannot cd to Fil-C source directory: $FILC_SOURCE_DIR"
    exit 1
}

log "Current directory: $(pwd)"
log "Fil-C branch: $FILC_BRANCH"
log "Target libc: $FILC_LIBC"
log "Install prefix: $FILC_PREFIX"

# ====================== Fix library detection for Alpine ======================
if [[ -f /etc/alpine-release ]]; then
    log "Alpine detected - setting CMake library paths..."

    export CMAKE_PREFIX_PATH="/usr"
    export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/local/lib/pkgconfig"
    
    # Explicitly tell CMake where to find libxml2 and curl
    export LIBXML2_LIBRARY="/usr/lib/libxml2.so"
    export LIBXML2_INCLUDE_DIR="/usr/include/libxml2"
    export CURL_LIBRARY="/usr/lib/libcurl.so"
    export CURL_INCLUDE_DIR="/usr/include/curl"
fi

# ====================== Choose build script ======================
if [[ "$FILC_LIBC" == "musl" ]]; then
    BUILD_SCRIPT="build_all_fast_musl.sh"
    log "Using musl variant"
else
    BUILD_SCRIPT="build_all_fast_glibc.sh"
    log "Using glibc variant (recommended)"
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

# ====================== Setup Fil-C installation ======================
log "Setting up Fil-C installation in $FILC_PREFIX"

if [[ -d "/opt/fil" ]]; then
    log "Fil-C appears to be installed in /opt/fil"
    mkdir -p /usr/local/bin
    ln -sf /opt/fil/bin/filcc /usr/local/bin/filcc 2>/dev/null || true
    ln -sf /opt/fil/bin/fil++ /usr/local/bin/fil++ 2>/dev/null || true
else
    log "WARNING: /opt/fil directory not found. Build script may use a different prefix."
fi

# Verify compiler
log "Verifying filcc installation..."
if command -v filcc >/dev/null; then
    filcc --version | head -n 5
    log "filcc version check passed."
else
    log "WARNING: filcc command not found in PATH."
fi

log "Phase 02 completed successfully!"
log "Fil-C compiler and runtime have been built."

echo ""
echo "Next step: Phase 03 (setup-dual-libc.sh) — the critical LC transition."

exit 0
