#!/bin/bash
set -euo pipefail

echo "=== Fil-C Bootstrap Test Setup in Alpine ==="

# Update and install required packages
apk update
apk upgrade -a

apk add --no-cache \
    bash git curl wget \
    build-base clang clang-dev llvm llvm-dev \
    cmake ninja \
    patchelf rsync tar \
    alpine-base

echo "Packages installed successfully."

cd ~/filc-bootstrap

# Make scripts executable
chmod +x bootstrap.sh phases/*.sh

echo ""
echo "=== Setup completed successfully! ==="
echo "You can now run the test with:"
echo "   ./bootstrap.sh --test-alpine"
echo ""
echo "Or run with extra safety:"
echo "   ./bootstrap.sh --test-alpine --fresh"
