#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget build-essential ca-certificates

git clone https://github.com/orsonteodoro/filc-bootstrap.git
cd filc-bootstrap

chmod +x bootstrap.sh phases/*.sh

echo "You may run ./bootstrap.sh --test-debian in filc-bootstrap folder"
