#!/bin/bash
# setup-filc-test.sh - One-command setup for filc-bootstrap test in Alpine
# Only run in Alpine VM guest

set -euo pipefail

echo "=== Fil-C Bootstrap Test Setup in Alpine ==="

apk update && apk upgrade -a

apk add --no-cache \
    bash git curl wget \
    build-base clang clang-dev llvm llvm-dev \
    cmake ninja patchelf rsync tar

mkdir -p ~/filc-test
cd ~/filc-test

if [[ ! -d filc-bootstrap ]]; then
    git clone https://github.com/OrsonTeodoro/filc-bootstrap.git
fi

cd filc-bootstrap
chmod +x bootstrap.sh phases/*.sh

echo "Setup complete! Running test..."
echo "Running: ./bootstrap.sh --test-alpine"

./bootstrap.sh --test-alpine
