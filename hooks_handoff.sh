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

    # This is where we would:
    # - Add the filc-overlay to /etc/portage/repos.conf
    # - Set CC=filcc and CXX=fil++ in make.conf
    # - Emerge @system and @world with the new compiler

    log "Gentoo handoff hook is a placeholder for now."
    log "TODO: Integrate with filc-overlay and set compiler in make.conf"
    log "      Then run: emerge -e @system && emerge -ve @world"
}

# ====================== Alpine Handoff Hook ======================
alpine_handoff() {
    log "Alpine: Performing final handoff..."

    ln -sf /opt/fil/bin/filcc /usr/local/bin/filcc 2>/dev/null || true
    ln -sf /opt/fil/bin/fil++ /usr/local/bin/fil++ 2>/dev/null || true

    log "✅ Alpine handoff completed. filcc/fil++ are now in PATH."
}
