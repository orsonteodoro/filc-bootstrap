#!/bin/bash
# =============================================================================
# Phase 02 - Build Fil-C Toolchain
# Builds the Fil-C compiler, runtime (libpizlo.so), yolo libc, and user libc
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

# ====================== Choose the correct build script ======================
if [[ "$FILC_LIBC" == "musl" ]]; then
    BUILD_SCRIPT="build_all_fast_musl.sh"
    log "Using musl variant: $BUILD_SCRIPT"
else
    BUILD_SCRIPT="build_all_fast_glibc.sh"
    log "Using glibc variant (recommended): $BUILD_SCRIPT"
fi

if [[ ! -f "./$BUILD_SCRIPT" ]]; then
    log "ERROR: Build script $BUILD_SCRIPT not found in Fil-C source!"
    ls -la
    exit 1
fi

# ====================== Build Fil-C (this can take a long time) ======================
log "Starting Fil-C build with $BUILD_SCRIPT ..."
log "This step can take 30 minutes to several hours depending on hardware."

# Make the build script executable
chmod +x "./$BUILD_SCRIPT"

# Run the build
if ./"$BUILD_SCRIPT"; then
    log "Fil-C build completed successfully."
else
    log "ERROR: Fil-C build failed. Check the log above for details."
    exit 1
fi

# ====================== Setup Fil-C installation ======================
log "Setting up Fil-C installation in $FILC_PREFIX"

# Many of the build scripts install to /opt/fil or similar.
# We make sure it's in the expected location and create symlinks if needed.
if [[ -d "/opt/fil" ]]; then
    log "Fil-C appears to be installed in /opt/fil"
    # Create convenient symlinks in /usr/local if desired
    mkdir -p /usr/local/bin
    ln -sf /opt/fil/bin/filcc /usr/local/bin/filcc 2>/dev/null || true
    ln -sf /opt/fil/bin/fil++ /usr/local/bin/fil++ 2>/dev/null || true
else
    log "WARNING: /opt/fil directory not found. Build script may use a different prefix."
    log "Please check where Fil-C was installed."
fi

# Verify the compiler works
log "Verifying filcc installation..."
if command -v filcc >/dev/null; then
    filcc --version | head -n 5
    log "filcc version check passed."
else
    log "WARNING: filcc command not found in PATH."
    log "You may need to add $FILC_PREFIX/bin to your PATH manually."
fi

# ====================== Create checkpoint snapshot ======================
if [[ "$CREATE_SNAPSHOTS" == "true" ]]; then
    SNAPSHOT_NAME="${SNAPSHOT_PREFIX}-post-phase02-$(date '+%Y%m%d-%H%M%S').tar.gz"
    log "Creating post-phase02 snapshot: $BACKUP_DIR/$SNAPSHOT_NAME"
    mkdir -p "$BACKUP_DIR"
    tar -czf "$BACKUP_DIR/$SNAPSHOT_NAME" \
        --exclude=/proc \
        --exclude=/sys \
        --exclude=/dev \
        --exclude=/run \
        --exclude=/tmp \
        /opt/fil /usr/local/bin/filcc /usr/local/bin/fil++ 2>/dev/null || true
    log "Snapshot created."
fi

log "Phase 02 completed successfully!"
log "Fil-C compiler, runtime, and dual-libc components have been built."

echo ""
echo "Next step: Phase 03 (setup-dual-libc.sh) — the critical LC transition."

exit 0
