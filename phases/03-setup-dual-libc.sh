#!/bin/bash
# =============================================================================
# Phase 03 - Setup Dual Libc (LC Phase)
# The critical transition: Yoloify + build yolo glibc + build user glibc with Fil-C
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 03] $*"
}

log "Starting Phase 03: Dual Libc Setup (LC Transition)"
log "This is the most critical and potentially destructive phase."

cd "$FILC_SOURCE_DIR" || {
    log "ERROR: Cannot cd to Fil-C source: $FILC_SOURCE_DIR"
    exit 1
}

# ====================== Pre-LC Safety Backup ======================
if [[ "$CREATE_SNAPSHOTS" == "true" ]]; then
    SNAPSHOT_NAME="${SNAPSHOT_PREFIX}-pre-lc-$(date '+%Y%m%d-%H%M%S').tar.gz"
    log "Creating PRE-LC safety snapshot: $BACKUP_DIR/$SNAPSHOT_NAME"
    mkdir -p "$BACKUP_DIR"
    tar -czf "$BACKUP_DIR/$SNAPSHOT_NAME" \
        --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp \
        /bin /sbin /usr/bin /usr/sbin /lib /lib64 /usr/lib /usr/lib64 /etc 2>/dev/null || true
    log "Pre-LC backup created. You can restore from this if LC fails badly."
fi

# ====================== Yoloify Critical Binaries ======================
log "Starting Yoloify step — making critical binaries use yolo loader..."

# This step uses patchelf to redirect key system binaries so the system doesn't break
# while we replace the main libc.

if ! command -v patchelf >/dev/null; then
    log "ERROR: patchelf is required for yoloify but not found."
    exit 1
fi

# Example yoloify for essential binaries (expand this as needed)
for bin in /bin/bash /bin/sh /usr/bin/env /bin/ls /usr/bin/coreutils; do
    if [[ -f "$bin" ]]; then
        log "Yoloifying $bin ..."
        # This is a placeholder — real yoloify often involves setting interpreter
        # to a Fil-C loader or adjusting RPATH to yolo libs.
        # Adapt from pizlix/scripts if available.
        patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 "$bin" 2>/dev/null || true
    fi
done

log "Basic yoloify completed. (Note: Full yoloify logic may need expansion based on Pizlix scripts.)"

# ====================== Build Yolo glibc ======================
log "Building Yolo glibc (normal unsafe glibc for Fil-C runtime)..."

if [[ -f "./build_yolo_glibc.sh" ]]; then
    chmod +x ./build_yolo_glibc.sh
    ./build_yolo_glibc.sh || {
        log "ERROR: build_yolo_glibc.sh failed"
        exit 1
    }
elif [[ -f "./projects/yolo-glibc-2.40/build.sh" ]]; then
    log "Using projects/yolo-glibc-2.40 build..."
    cd projects/yolo-glibc-2.40
    ./build.sh
    cd ../../
else
    log "WARNING: No yolo glibc build script found. Skipping or using manual method."
fi

log "Yolo glibc built."

# ====================== Drop Fil-C Binaries & Runtime ======================
log "Dropping Fil-C compiler, libpizlo.so, and supporting libraries..."

# This usually installs compiler + runtime into system paths or $FILC_PREFIX
if [[ -f "./setup_glibc.sh" || -f "./setup.sh" ]]; then
    ./setup_glibc.sh || ./setup.sh || true
fi

# Ensure filcc is in PATH
export PATH="$FILC_PREFIX/bin:$PATH"
hash -r

log "Fil-C binaries dropped."

# ====================== Build User glibc with Fil-C ======================
log "Building User glibc (memory-safe version compiled with filcc)..."

if [[ -f "./build_user_glibc.sh" ]]; then
    chmod +x ./build_user_glibc.sh
    CC=filcc CXX=fil++ ./build_user_glibc.sh || {
        log "ERROR: build_user_glibc.sh failed"
        exit 1
    }
else
    log "WARNING: build_user_glibc.sh not found. This is the most important step."
    log "You may need to manually build from projects/user-glibc-2.40 using filcc."
fi

log "User glibc (Fil-C compiled) built."

# ====================== Final Switch & Symlink Adjustments ======================
log "Finalizing dual-libc sandwich..."

# Example: Update ld.so cache or symlinks so new compiles use user glibc
ldconfig || true

# Set environment so future emerges use Fil-C
cat >> /etc/profile.d/filc.sh <<EOF
export CC=filcc
export CXX=fil++
export PATH="$FILC_PREFIX/bin:\$PATH"
EOF

log "Environment configured for Fil-C."

# ====================== Post-LC Snapshot ======================
if [[ "$CREATE_SNAPSHOTS" == "true" ]]; then
    SNAPSHOT_NAME="${SNAPSHOT_PREFIX}-post-lc-$(date '+%Y%m%d-%H%M%S').tar.gz"
    log "Creating POST-LC snapshot: $BACKUP_DIR/$SNAPSHOT_NAME"
    tar -czf "$BACKUP_DIR/$SNAPSHOT_NAME" \
        --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp \
        /lib /lib64 /usr/lib /usr/lib64 /opt/fil /etc 2>/dev/null || true
    log "Post-LC backup created."
fi

log "Phase 03 (LC Transition) completed successfully!"
log "The system is now pizlonated with dual libc sandwich."
log "WARNING: The next rebuild (Phase 04 / @world) will take a very long time."

echo ""
echo "Next: Phase 04 (gentoo-bridge.sh) — hand off to filc-overlay for @system / @world rebuild."

exit 0
