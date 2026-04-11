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

# Create working directory
mkdir -p ~/filc-test
cd ~/filc-test

# Clone your repository
if [[ ! -d filc-bootstrap ]]; then
    echo "Cloning filc-bootstrap repository..."
    git clone https://github.com/OrsonTeodoro/filc-bootstrap.git
fi

cd filc-bootstrap

# Make scripts executable
chmod +x bootstrap.sh phases/*.sh

echo ""
echo "=== Setup completed successfully! ==="
echo "You can now run the test with:"
echo "   ./bootstrap.sh --test-alpine"
echo ""
echo "Or run with extra safety:"
echo "   ./bootstrap.sh --test-alpine --fresh"
