# ROS2 Humble + MoveIt2 + Berkeley Humanoid Lite (Jetson TX2 / arm64)
FROM ros:humble-ros-base

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
      ros-humble-moveit \
      ros-humble-robot-state-publisher \
      ros-humble-joint-state-publisher \
      ros-humble-xacro \
      ros-humble-ros2-control \
      ros-humble-ros2-controllers \
      python3-pip python3-colcon-common-extensions \
      can-utils net-tools iproute2 git nano \
    && rm -rf /var/lib/apt/lists/*

# evdev (pynput dep) fails to build from pip on this base -> take it from apt
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3-dev build-essential python3-evdev \
    && rm -rf /var/lib/apt/lists/*

# Berkeley Humanoid Lite lowlevel / sim2sim / teleop deps (no Isaac Lab: x86 + RTX only)
# onnxruntime>=1.19 aborts on import on TX2 (cpuinfo assertion) -> pin 1.18.1
RUN pip3 install --no-cache-dir \
      "numpy<2" omegaconf pyaml pyserial python-can cc.udp inputs pynput \
      onnxruntime==1.18.1 loop_rate_limiters psutil scipy mujoco \
      pin pin-pink "qpsolvers[quadprog]" meshcat meshcat_shapes

# torch (CPU build) is imported by lowlevel rl_controller / sim2sim
RUN pip3 install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc && \
    echo "[ -f /ws/install/setup.bash ] && source /ws/install/setup.bash" >> /root/.bashrc

WORKDIR /ws
