#!/bin/bash
# Upstream path mismatches in berkeley_humanoid_lite_assets (as of fc90fed):
#  - MJCF looks for meshes at mjcf/assets/merged/*.stl, files live in meshes/
#  - environments/mujoco.py loads data/mjcf/bhl_scene.xml, file lives in data/robots/.../mjcf/
# Fix with symlinks so the upstream code stays untouched.
set -e
ASSETS="${1:-$HOME/bhl_ws/src/berkeley-humanoid-lite/source/berkeley_humanoid_lite_assets}"
ROBOT_REL=robots/berkeley_humanoid/berkeley_humanoid_lite

mkdir -p "$ASSETS/data/$ROBOT_REL/mjcf/assets"
ln -sfn ../../meshes "$ASSETS/data/$ROBOT_REL/mjcf/assets/merged"
ln -sfn "$ROBOT_REL/mjcf" "$ASSETS/data/mjcf"
echo "symlinks created under $ASSETS/data"
