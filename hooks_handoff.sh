#!/bin/bash
# =============================================================================
# hooks_handoff.sh - Final handoff / integration hooks
# This is where we set up the compiler as default, add overlays/repos, etc.
# =============================================================================

# ====================== Debian Handoff Hook ======================
debian_handoff() {
    log "Debian: Performing final handoff..."

    # Create symlinks for easy use
    ln -sf /opt/fil/bin/filcc /usr/local/bin/filcc 2>/dev/null || true
    ln -sf /opt/fil/bin/fil++ /usr/local/bin/fil++ 2>/dev/null || true

    # Optional: Add to alternatives so filcc is preferred
    update-alternatives --install /usr/bin/cc cc /opt/fil/bin/filcc 100 2>/dev/null || true
    update-alternatives --install /usr/bin/c++ c++ /opt/fil/bin/fil++ 100 2>/dev/null || true

    log "✅ Debian handoff completed. filcc/fil++ are now available."
    log "   You can now compile with: filcc hello.c -o hello"
}

# ====================== Gentoo Handoff Hook ======================
gentoo_handoff() {
    log "Gentoo: Performing final handoff to filc-overlay..."

    # Create symlinks
    mkdir -p /usr/local/bin
    ln -sf /opt/fil/bin/filcc /usr/local/bin/filcc 2>/dev/null || true
    ln -sf /opt/fil/bin/fil++ /usr/local/bin/fil++ 2>/dev/null || true

    # Basic make.conf adjustments for Fil-C
    if [[ -f /etc/portage/make.conf ]]; then
        log "Updating /etc/portage/make.conf for Fil-C..."

        # Backup original
        cp /etc/portage/make.conf /etc/portage/make.conf.bak 2>/dev/null || true

        # Add Fil-C settings (commented so user can enable them)
        cat >> /etc/portage/make.conf << 'EOF'

# === Fil-C Configuration (uncomment to enable) ===
# CC="/opt/fil/bin/filcc"
# CXX="/opt/fil/bin/fil++"
# CFLAGS="${CFLAGS} -fPIC"
# CXXFLAGS="${CXXFLAGS} -fPIC"
EOF
    fi

    log "✅ Gentoo handoff completed."
    log "   filcc and fil++ are available in /usr/local/bin"
    log "   Next step: emerge -e @system (this will take a long time)"
    log "   Then: emerge -ve @world"
}

# ====================== Alpine Handoff Hook ======================
alpine_handoff() {
    log "Alpine: Performing final handoff..."

    ln -sf /opt/fil/bin/filcc /usr/local/bin/filcc 2>/dev/null || true
    ln -sf /opt/fil/bin/fil++ /usr/local/bin/fil++ 2>/dev/null || true

    log "✅ Alpine handoff completed. filcc/fil++ are now in PATH."
}
