#!/bin/bash
# Run INSIDE the bhl container to check that ROS2 / MoveIt2 / Berkeley deps work.
source /opt/ros/humble/setup.bash
BHL=/ws/src/berkeley-humanoid-lite
ROBOT=$BHL/source/berkeley_humanoid_lite_assets/data/robots/berkeley_humanoid/berkeley_humanoid_lite

echo "== Python: $(python3 --version)"
echo "== ROS_DISTRO: $ROS_DISTRO"
echo "== MoveIt2 packages: $(ros2 pkg list | grep -c '^moveit')"
ros2 pkg prefix moveit_ros_move_group

python3 - <<EOF
import numpy, onnxruntime, mujoco, pinocchio, pink, can, omegaconf, scipy, qpsolvers, meshcat
from cc.udp import UDP
print("== Python deps OK: numpy", numpy.__version__, "| onnxruntime", onnxruntime.__version__,
      "| mujoco", mujoco.__version__, "| pinocchio", pinocchio.__version__)

s = onnxruntime.InferenceSession("$BHL/checkpoints/policy_humanoid.onnx")
print("== Policy ONNX loaded, inputs:", [(i.name, i.shape) for i in s.get_inputs()])

m = mujoco.MjModel.from_xml_path("$ROBOT/mjcf/bhl_scene.xml")
d = mujoco.MjData(m)
for _ in range(100):
    mujoco.mj_step(m, d)
print("== MuJoCo model OK: nq =", m.nq, "nu =", m.nu)

r = pinocchio.buildModelFromUrdf("$ROBOT/urdf/berkeley_humanoid_lite.urdf")
print("== URDF (pinocchio) OK: joints =", r.njoints - 1)

import torch
print("== torch OK:", torch.__version__)

from berkeley_humanoid_lite_lowlevel.robot import Humanoid
from berkeley_humanoid_lite_lowlevel.policy.rl_controller import RlController
from berkeley_humanoid_lite.environments import MujocoSimulator
print("== Berkeley Humanoid Lite packages import OK")
EOF
