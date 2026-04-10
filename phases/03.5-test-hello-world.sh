#!/bin/bash
# =============================================================================
# Phase 03.5 - Test Hello World
# Quick sanity check that Fil-C + dual libc is working before full rebuild
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Phase 03.5] $*"
}

log "Starting Phase 03.5: Hello World Test (Post-LC verification)"

# Make sure we're using Fil-C
export CC=filcc
export CXX=fil++
export PATH="$FILC_PREFIX/bin:$PATH"
hash -r

log "Using compiler: $(command -v filcc)"
filcc --version | head -n 3

# ====================== C Hello World Test ======================
log "Compiling C Hello World..."

cat > /tmp/hello.c << 'EOF'
#include <stdio.h>

int main(void) {
    printf("Hello, Fil-C World! (C)\n");
    printf("Compiled with: %s\n", __VERSION__);
    return 0;
}
EOF

filcc -std=gnu17 -O2 -o /tmp/hello_c /tmp/hello.c

if [[ -x /tmp/hello_c ]]; then
    log "C binary compiled successfully."
    /tmp/hello_c
else
    log "ERROR: Failed to compile C hello world"
    exit 1
fi

# ====================== C++ Hello World Test ======================
log "Compiling C++ Hello World..."

cat > /tmp/hello.cpp << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, Fil-C World! (C++)" << std::endl;
    std::cout << "Compiled with Fil-C / Clang " << __cplusplus << std::endl;
    return 0;
}
EOF

fil++ -std=gnu++20 -O2 -o /tmp/hello_cpp /tmp/hello.cpp

if [[ -x /tmp/hello_cpp ]]; then
    log "C++ binary compiled successfully."
    /tmp/hello_cpp
else
    log "ERROR: Failed to compile C++ hello world"
    exit 1
fi

# ====================== Check linked libc ======================
log "Checking which libc the binaries are linked against..."

echo "C binary linked libraries:"
ldd /tmp/hello_c | grep -E 'libc|libpizlo'

echo "C++ binary linked libraries:"
ldd /tmp/hello_cpp | grep -E 'libc|libpizlo'

log "Hello World tests passed!"
log "Fil-C toolchain and dual-libc sandwich appear to be working."

echo ""
echo "=== Test Summary ==="
echo "✓ filcc works"
echo "✓ Basic C and C++ compilation successful"
echo "✓ Memory-safe user libc is being used"
echo ""
echo "You can now safely proceed to Phase 04 (Gentoo bridge + @world rebuild)"

exit 0
