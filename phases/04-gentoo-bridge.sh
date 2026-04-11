#!/bin/bash
# =============================================================================
# Phase 04 - Gentoo Bridge / Hand-off
# Prepares the system for filc-overlay and starts the final rebuild
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 04] $*"
}

log "Starting Phase 04: Gentoo Bridge (Post-LC hand-off to filc-overlay)"

# Safety check — make sure we're in Gentoo
if [[ ! -f /etc/gentoo-release ]]; then
    log "ERROR: This phase is only for Gentoo systems."
    log "Skipping Gentoo bridge."
    exit 0
fi

log "Detected Gentoo — proceeding with toolchain integration."

# ====================== Copy bootstrap repo into persistent location ======================
log "Ensuring filc-bootstrap is available in /root..."
mkdir -p /root/filc-bootstrap
cp -a "$SCRIPT_DIR"/.. /root/filc-bootstrap/ 2>/dev/null || true

# ====================== Add filc-overlay ======================
log "Adding filc-overlay to Portage..."

OVERLAY_DIR="/var/db/repos/filc-overlay"

if [[ -d "$OVERLAY_DIR" ]]; then
    log "filc-overlay already exists. Updating..."
    cd "$OVERLAY_DIR"
    git pull || true
else
    log "Cloning filc-overlay..."
    mkdir -p /var/db/repos
    git clone https://github.com/orsonteodoro/filc-overlay.git "$OVERLAY_DIR" || {
        log "WARNING: Could not clone filc-overlay. Please add it manually."
    }
fi

# Register the overlay in Portage
if [[ -f /etc/portage/repos.conf/filc-overlay.conf ]]; then
    log "filc-overlay already registered."
else
    cat > /etc/portage/repos.conf/filc-overlay.conf <<EOF
[filc-overlay]
location = $OVERLAY_DIR
priority = 50
auto-sync = yes
EOF
    log "filc-overlay registered in Portage."
fi

# ====================== Set Fil-C as default toolchain ======================
log "Setting Fil-C as the active compiler..."

# Create environment file
cat > /etc/profile.d/filc-toolchain.sh <<'EOF'
export CC=filcc
export CXX=fil++
export PATH="/opt/fil/bin:${PATH}"
EOF

chmod +x /etc/profile.d/filc-toolchain.sh
source /etc/profile.d/filc-toolchain.sh

# Optional: Create eselect-like symlink (if you add eselect support later)
ln -sf /opt/fil/bin/filcc /usr/bin/cc 2>/dev/null || true
ln -sf /opt/fil/bin/fil++ /usr/bin/c++ 2>/dev/null || true

log "Fil-C toolchain activated (CC=filcc, CXX=fil++)"

# ====================== Recommended make.conf adjustments ======================
log "Applying recommended make.conf settings for Fil-C..."

cat >> /etc/portage/make.conf <<'EOF'

# Fil-C specific settings
CC=filcc
CXX=fil++

# Since Fil-C defaults to strict ISO modes, enable GNU extensions where needed
CFLAGS="${CFLAGS} -std=gnu17"
CXXFLAGS="${CXXFLAGS} -std=gnu++20"

# Fil-C has runtime overhead — you may want to reduce optimization initially
# CFLAGS="${CFLAGS} -O2 -pipe"

EOF

log "make.conf updated with Fil-C defaults."

# ====================== Emerge the overlay packages ======================
log "Emerging filc-overlay packages..."

emerge -av --noreplace \
    sys-devel/fil-c \
    sys-libs/user-glibc-filc || {
    log "WARNING: Some filc-overlay packages failed to emerge. Continuing anyway."
}

# ====================== Final Verification ======================
log "Final verification before full rebuild..."

filcc --version | head -n 3
echo "CC = $(command -v $CC)"
echo "CXX = $(command -v $CXX)"

# Quick test again
echo 'int main(){printf("Fil-C ready!\n");}' | filcc -x c - -o /tmp/test && /tmp/test

log "Phase 04 completed successfully!"
log "The system is now ready for the final rebuild."

echo ""
echo "======================================================================"
echo "NEXT STEPS — MANUAL RECOMMENDED COMMANDS:"
echo ""
echo "1. Review and adjust /etc/portage/make.conf if needed"
echo "2. Run the big rebuilds:"
echo "   emerge -e @system --keep-going"
echo "   emerge -ve @world --keep-going"
echo ""
echo "   (These will take many hours/days — use screen/tmux)"
echo ""
echo "3. After rebuild, update bootloader and reboot."
echo "======================================================================"

exit 0
