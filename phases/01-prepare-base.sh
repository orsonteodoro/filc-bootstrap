#!/bin/bash
# =============================================================================
# Phase 01 - Prepare Base Environment (Improved git + cache handling)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 01] $*"
}

log "Starting Phase 01: Prepare Base Environment"

# Ensure we are in the correct location inside chroot
if [[ ! -d /root/filc-bootstrap ]]; then
    log "Copying bootstrap scripts into chroot..."
    mkdir -p /root/filc-bootstrap
    cp -a "$SCRIPT_DIR"/.. /root/filc-bootstrap/ 2>/dev/null || true
fi
cd /root/filc-bootstrap

# ====================== Distro Detection ======================
if [[ -f /etc/gentoo-release ]]; then
    DISTRO="gentoo"
    log "Detected Gentoo"
elif [[ -f /etc/alpine-release ]]; then
    DISTRO="alpine"
    log "Detected Alpine"
else
    DISTRO="unknown"
    log "WARNING: Unknown distribution"
fi

# ====================== DNS Check ======================
log "Verifying DNS resolution..."
if ! ping -c 1 -W 5 -q google.com >/dev/null 2>&1; then
    log "DNS failed. Applying fallback public DNS..."
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    chmod 644 /etc/resolv.conf
fi
log "DNS is working."

# ====================== Git Cache Setup ======================
mkdir -p "$GIT_CACHE_DIR"

# ====================== Clone / Update Fil-C (with cache + pinned commit support) ======================
log "Setting up Fil-C source at $FILC_SOURCE_DIR"

if [[ -d "$FILC_SOURCE_DIR/.git" ]]; then
    log "Updating existing Fil-C repository..."
    cd "$FILC_SOURCE_DIR"
    git fetch --progress origin
else
    log "Cloning Fil-C repository..."
    mkdir -p "$(dirname "$FILC_SOURCE_DIR")"

    if [[ -d "$GIT_CACHE_DIR/fil-c.git" ]]; then
        log "Using git cache for faster clone..."
        git clone --reference "$GIT_CACHE_DIR/fil-c.git" --progress "$FILC_REPO" "$FILC_SOURCE_DIR"
    else
        if [[ "$GIT_SHALLOW" == "true" && -z "$FILC_COMMIT" && "$FILC_USE_TAG" != "true" ]]; then
            git clone --progress --depth 1 --branch "$FILC_BRANCH" "$FILC_REPO" "$FILC_SOURCE_DIR"
        else
            git clone --progress --branch "$FILC_BRANCH" "$FILC_REPO" "$FILC_SOURCE_DIR"
        fi
        # Create cache for future runs
        cp -a "$FILC_SOURCE_DIR/.git" "$GIT_CACHE_DIR/fil-c.git" 2>/dev/null || true
    fi
    cd "$FILC_SOURCE_DIR"
fi

# Checkout logic
git checkout "$FILC_BRANCH" || true

if [[ "$FILC_USE_TAG" == "true" && -n "$FILC_TAG" ]]; then
    log "Checking out tag: $FILC_TAG"
    git fetch --tags --progress
    git checkout "$FILC_TAG" || log "WARNING: Tag $FILC_TAG not found"
elif [[ -n "$FILC_COMMIT" ]]; then
    log "Pinning to commit: $FILC_COMMIT"
    if git cat-file -e "$FILC_COMMIT" 2>/dev/null; then
        git checkout "$FILC_COMMIT"
    else
        log "Fetching specific commit..."
        git fetch origin "$FILC_COMMIT"
        git checkout "$FILC_COMMIT"
    fi
    log "Successfully checked out commit $FILC_COMMIT"
fi

# Final verification with recovery
if [[ ! -f "$FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "WARNING: build scripts not found after checkout. Resetting to branch tip..."
    git checkout "$FILC_BRANCH"
    git pull --ff-only --progress || true
fi

if [[ ! -f "$FILC_SOURCE_DIR/build_all_fast_glibc.sh" ]]; then
    log "ERROR: Fil-C build scripts still not found!"
    log "Current directory: $(pwd)"
    ls -la
    exit 1
fi

log "Fil-C source ready."
log "Current commit: $(git rev-parse --short HEAD) - $(git log -1 --oneline)"

# ====================== Install Dependencies ======================
log "Installing build dependencies..."

if [[ "$DISTRO" == "alpine" ]]; then
    apk add --no-cache \
        bash git curl wget ca-certificates \
        build-base clang clang-dev llvm llvm-dev \
        cmake ninja patchelf rsync tar
elif [[ "$DISTRO" == "gentoo" ]]; then
    emerge --sync --quiet || log "WARNING: emerge --sync failed"
    emerge -av --noreplace git clang llvm cmake ninja patchelf quilt rsync tar wget curl
fi

log "Build dependencies installed."

# ====================== Snapshot ======================
if [[ "$CREATE_SNAPSHOTS" == "true" ]]; then
    SNAPSHOT_NAME="${SNAPSHOT_PREFIX}-post-phase01-$(date '+%Y%m%d-%H%M%S').tar.gz"
    log "Creating post-phase01 snapshot..."
    mkdir -p "$BACKUP_DIR"
    tar -czf "$BACKUP_DIR/$SNAPSHOT_NAME" \
        --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp \
        /bin /usr/bin /lib /usr/lib /etc 2>/dev/null || true
fi

log "Phase 01 completed successfully!"
log "Ready for Phase 02: Building Fil-C toolchain."

exit 0
