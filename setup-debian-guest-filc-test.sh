#!/bin/bash
apt update && apt upgrade -y
apt install -y git curl wget build-essential ca-certificates

cd ~/filc-bootstrap

chmod +x bootstrap.sh phases/*.sh

echo "You may run ./bootstrap.sh --test-debian in filc-bootstrap folder"
