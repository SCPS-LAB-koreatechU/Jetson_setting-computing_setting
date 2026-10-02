#!/bin/bash
# Start (or attach to) the ROS2 Humble dev container.
# host network + privileged: ROS2 DDS discovery and CAN (can0..3) / USB serial access
NAME=bhl
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  docker start "$NAME" >/dev/null
  exec docker exec -it "$NAME" bash
fi
xhost +local:root >/dev/null 2>&1
SRC=/ws/src/berkeley-humanoid-lite/source
exec docker run -it --name "$NAME" \
  -e PYTHONPATH=$SRC/berkeley_humanoid_lite:$SRC/berkeley_humanoid_lite_lowlevel:$SRC/berkeley_humanoid_lite_assets \
  --network host --privileged \
  -v /dev:/dev \
  -e DISPLAY="$DISPLAY" -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$HOME/bhl_ws":/ws \
  bhl:humble bash
