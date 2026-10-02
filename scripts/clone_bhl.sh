#!/bin/bash
# Clone Berkeley Humanoid Lite into ~/bhl_ws/src.
# Its .gitmodules use SSH URLs; rewrite them to HTTPS so no GitHub SSH key is needed.
set -e
mkdir -p "$HOME/bhl_ws/src"
cd "$HOME/bhl_ws/src"
[ -d berkeley-humanoid-lite ] || git clone https://github.com/HybridRobotics/berkeley-humanoid-lite.git
cd berkeley-humanoid-lite
git -c url."https://github.com/".insteadOf="git@github.com:" submodule update --init --recursive
git submodule status
