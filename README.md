# Jetson_setting-computing_setting

Jetson TX2에서 **Berkeley Humanoid Lite(BHL)** 제어용 온디바이스 개발 환경(ROS2 Humble + MoveIt2 + BHL 저수준 제어 코드)을 구성하는 방법을 정리한 인수인계 문서입니다.

> 작성일: 2026-10-02 · 검증 장비: Jetson TX2 (`ttt-desktop`)

---

## 0. 요약 (TL;DR)

```bash
# (호스트, 최초 1회) Docker 권한 + CAN 드라이버
./scripts/setup_host.sh          # sudo 비밀번호 필요, 끝나면 재로그인

# (호스트) BHL 코드 받기 + 경로 패치
./scripts/clone_bhl.sh
./scripts/fix_bhl_paths.sh

# (호스트) 이미지 빌드 (~1시간, 3.2GB)
cd docker && docker build -t bhl:humble .

# (호스트) 동작 확인 → 4-5 참고
# (호스트) 컨테이너 진입
./docker/run.sh
```

---

## 1. 왜 Docker를 쓰는가

| 항목 | 호스트(TX2) | 필요 조건 |
|---|---|---|
| OS | Ubuntu **18.04** (JetPack 4.x, L4T R32.5.2) | ROS2 Humble/MoveIt2 → Ubuntu **22.04** |
| Python | **3.6.9** | BHL lowlevel → Python **≥ 3.10** |
| Arch | aarch64 | — |

- TX2는 공식적으로 JetPack 4.x(Ubuntu 18.04)까지만 지원되므로 OS 업그레이드는 비권장.
- 대신 **Ubuntu 22.04 기반 `ros:humble-ros-base` (arm64) 컨테이너**를 사용 → ROS2 Humble, MoveIt2(apt 바이너리, 소스 빌드 불필요), Python 3.10을 한 번에 해결.
- CAN/USB 장치는 `--privileged -v /dev:/dev --network host`로 컨테이너에 그대로 노출.

## 2. 구성 요소 및 버전

### 호스트 (Jetson TX2)
| 프로그램 | 버전 | 비고 |
|---|---|---|
| Docker | 20.10.21 | 사용자 `ttt`를 `docker` 그룹에 추가 |
| CAN 커널 모듈 | 커널 내장 | `can`, `can_raw`, `can_dev`, `gs_usb`(USB-CAN), `mttcan`(TX2 내장 CAN) |
| can-utils | apt | `candump`, `cansend` 등 |

### 컨테이너 (`bhl:humble`, 약 3.2GB)
| 프로그램 | 버전 | 용도 |
|---|---|---|
| Ubuntu | 22.04 | 베이스 |
| ROS2 | Humble (ros-base 0.10.0) | 미들웨어 |
| MoveIt2 | 2.5.10 (`ros-humble-moveit`) | 모션 플래닝 (팔 매니퓰레이션 등) |
| ros2_control / ros2_controllers | 2.54.x | 하드웨어 인터페이스 |
| robot_state_publisher, joint_state_publisher, xacro | Humble | URDF 시각화/TF |
| Python | 3.10.12 | |
| onnxruntime | **1.18.1 (고정)** | RL 정책 추론 — 아래 트러블슈팅 참고 |
| torch | 2.14.1+cpu | lowlevel `rl_controller`에서 사용 |
| mujoco | 3.14.0 | sim2sim |
| pinocchio(`pin`), pin-pink, qpsolvers[quadprog] | 2.7.0 / latest | 텔레옵 IK |
| python-can, pyserial, cc.udp, inputs, pynput, omegaconf, meshcat | latest | BHL lowlevel 의존성 |

**설치하지 않은 것:** Isaac Sim / Isaac Lab (RL 학습용) — x86_64 + RTX GPU 전용이라 TX2에서는 불가. 학습은 별도 x86 PC에서 하고, 결과 `.onnx`만 TX2로 가져와서 실행합니다.

## 3. 디렉터리 구조

```
~/Jetson_setting-computing_setting/   ← 이 저장소
├── docker/
│   ├── Dockerfile        # bhl:humble 이미지 정의
│   └── run.sh            # 컨테이너 생성/재진입
└── scripts/
    ├── setup_host.sh     # 호스트: docker 그룹, CAN 모듈 (sudo)
    ├── clone_bhl.sh      # BHL 저장소 + 서브모듈 클론 (HTTPS)
    ├── fix_bhl_paths.sh  # BHL 에셋 경로 불일치 심볼릭 링크 패치
    └── verify_env.sh     # 컨테이너 안에서 환경 검증

~/bhl_ws/                              ← 작업 공간 (컨테이너의 /ws 로 마운트)
└── src/berkeley-humanoid-lite/        # HybridRobotics/berkeley-humanoid-lite
    └── source/
        ├── berkeley_humanoid_lite/          # sim 환경, 텔레옵
        ├── berkeley_humanoid_lite_assets/   # URDF / MJCF / STL (서브모듈)
        └── berkeley_humanoid_lite_lowlevel/ # CAN 모터 제어, RL 컨트롤러 (서브모듈)
```

## 4. 설치 절차 (새 TX2에서 처음부터)

### 4-1. 호스트 설정
```bash
git clone https://github.com/SCPS-LAB-koreatechU/Jetson_setting-computing_setting.git ~/Jetson_setting-computing_setting
cd ~/Jetson_setting-computing_setting
./scripts/setup_host.sh
```
그다음 **로그아웃 후 재로그인**(또는 재부팅)하세요. 그룹 변경은 이미 열려 있는 셸에는 적용되지 않습니다.
```bash
groups          # docker 가 보이면 OK
docker ps       # permission denied 가 안 나면 OK
```

### 4-2. BHL 코드 받기
```bash
./scripts/clone_bhl.sh      # ~/bhl_ws/src/berkeley-humanoid-lite
./scripts/fix_bhl_paths.sh  # MJCF 메시 / sim 경로 심볼릭 링크
```
> BHL의 `.gitmodules`는 SSH URL(`git@github.com:`)이라 SSH 키가 없으면 서브모듈이 비어 있게 됩니다. `clone_bhl.sh`는 HTTPS로 바꿔서 받습니다.

### 4-3. 이미지 빌드
```bash
cd ~/Jetson_setting-computing_setting/docker
docker build -t bhl:humble .
```
- TX2 기준 대략 1시간 이상 걸리고, 디스크 여유 공간이 **최소 5GB** 필요합니다(eMMC 28GB).

### 4-4. 컨테이너 실행
```bash
~/Jetson_setting-computing_setting/docker/run.sh
```
- 처음 실행하면 `bhl` 컨테이너를 만들고, 그다음부터는 같은 컨테이너에 다시 붙습니다(`docker exec`).
- `~/bhl_ws` ↔ `/ws` 마운트, host network, privileged(/dev 전체), X11 DISPLAY 전달.
- `PYTHONPATH`에 BHL 3개 패키지가 등록돼 있어서 `pip install` 없이 바로 import할 수 있습니다.
- 이미지를 새로 빌드했다면 기존 컨테이너를 지우고 다시 실행하세요: `docker rm -f bhl && ./docker/run.sh`

### 4-5. 동작 확인 (컨테이너 안)
호스트에서:
```bash
S=/ws/src/berkeley-humanoid-lite/source
docker run --rm -v ~/bhl_ws:/ws -v ~/Jetson_setting-computing_setting/scripts:/scripts \
  -e PYTHONPATH=$S/berkeley_humanoid_lite:$S/berkeley_humanoid_lite_lowlevel:$S/berkeley_humanoid_lite_assets \
  bhl:humble bash /scripts/verify_env.sh
```
정상 출력:
```
== Python: Python 3.10.12
== ROS_DISTRO: humble
== MoveIt2 packages: 26
== Python deps OK: numpy 1.26.4 | onnxruntime 1.18.1 | mujoco 3.14.0 | pinocchio 2.7.0
== Policy ONNX loaded, inputs: [('obs', [1, 75])]
== MuJoCo model OK: nq = 29 nu = 22
== URDF (pinocchio) OK: joints = 22
== torch OK: 2.14.1+cpu
== Berkeley Humanoid Lite packages import OK
```

## 5. 실기 운용 (BHL lowlevel)

모두 **컨테이너 안**에서 `/ws/src/berkeley-humanoid-lite/source/berkeley_humanoid_lite_lowlevel` 기준으로 실행합니다. 자세한 내용은 원본 README를 참고하세요.

CAN 인터페이스는 host network를 공유하므로 **호스트**에서 올리는 것이 간단합니다(컨테이너에는 sudo가 없음).
```bash
# (호스트) 1) CAN 버스 up (can0~can3, 1Mbps) — USB-CAN 어댑터 연결 후
sudo ~/bhl_ws/src/berkeley-humanoid-lite/source/berkeley_humanoid_lite_lowlevel/scripts/start_can_transports.sh
ip -br link show type can                # can0..3 UP 확인
```
```bash
# (컨테이너) 이후 단계
candump can0                             # 트래픽 확인

# 2) 관절 연결 확인
python3 scripts/check_connection.py

# 3) 관절 캘리브레이션 (전원 켤 때마다 필요) → calibration.yaml
python3 scripts/calibrate_joints.py

# 4) RL 보행 실행 (조이스틱: LB+A → init, RB+A → run, B → damping)
python3 scripts/run_locomotion.py
```
- 정책 파일: `berkeley-humanoid-lite/checkpoints/*.onnx`, 설정: `configs/policy_*.yaml`
- C++ 메인 컨트롤러(`make run`)를 쓰려면 컨테이너에 `cmake`와 libtorch를 추가해야 합니다(아직 미구성).

## 6. MoveIt2 사용 메모

- 설치: `ros-humble-moveit` (setup_assistant 포함) 완료.
- BHL URDF: `source/berkeley_humanoid_lite_assets/data/robots/berkeley_humanoid/berkeley_humanoid_lite/urdf/berkeley_humanoid_lite.urdf` (관절 22개: 다리 12 + 팔 10)
- **아직 하지 않은 작업:** BHL용 `moveit_config` 패키지 생성. 팔 planning group은 MoveIt Setup Assistant로 만들면 됩니다.
  ```bash
  ros2 launch moveit_setup_assistant setup_assistant.launch.py   # GUI 필요 (DISPLAY)
  ```
  생성한 패키지는 `~/bhl_ws/src/`에 두고 `/ws`에서 `colcon build`하세요. `.bashrc`가 `/ws/install/setup.bash`를 자동으로 source합니다.
- 보행(다리)은 MoveIt2가 아니라 RL 정책(ONNX)으로 제어합니다. MoveIt2는 팔 매니퓰레이션용입니다.
- RViz2는 TX2 + 컨테이너 OpenGL 환경에서 무겁거나 동작하지 않을 수 있습니다. 시각화는 같은 네트워크의 다른 PC(ROS2 Humble, 같은 `ROS_DOMAIN_ID`)에서 하는 것을 권장합니다.

## 7. 트러블슈팅 (실제로 겪은 문제)

| 증상 | 원인 | 해결 |
|---|---|---|
| `docker ps` → `permission denied` | `usermod -aG docker` 후 재로그인 안 함 | 재로그인 / `newgrp docker` / `sg docker -c "..."` |
| `import onnxruntime` 즉시 `Aborted (core dumped)` (`stl_vector.h ... Assertion '__n < this->size()'`) | onnxruntime **≥1.19**의 cpuinfo가 TX2 이종 코어(Denver2 + A57)를 처리 못 함 | **`onnxruntime==1.18.1`로 고정** (1.16~1.18 정상 확인) |
| `pthread_setaffinity_np failed ... error code: 22` 경고 | onnxruntime 스레드 affinity, TX2 코어 구성 | 무해함. 없애려면 `SessionOptions.intra_op_num_threads`를 명시 |
| pip가 `evdev` 버전을 계속 다운로드하며 멈춤 | `pynput` → `evdev` 소스 빌드 실패 | apt `python3-evdev` 먼저 설치 (Dockerfile 반영) |
| MuJoCo `Error opening file .../mjcf/assets/merged/*.stl` | BHL 에셋 경로 불일치 (업스트림) | `scripts/fix_bhl_paths.sh` |
| sim2sim이 `data/mjcf/bhl_scene.xml`을 못 찾음 | 동일 (업스트림) | `scripts/fix_bhl_paths.sh` |
| 서브모듈 폴더가 비어 있음 | `.gitmodules`가 SSH URL | `scripts/clone_bhl.sh` (HTTPS) |
| `pynput` ImportError: `Bad display name` | X 디스플레이 없음 | `run.sh`로 실행(DISPLAY 전달) 또는 GUI 세션에서 실행 |

## 8. 다음 할 일 (TODO)

- [ ] BHL 팔용 MoveIt2 config 생성 (Setup Assistant)
- [ ] BHL lowlevel ↔ ROS2 브리지 노드 (`/joint_states` 발행, MoveIt trajectory → CAN 명령)
- [ ] C++ 메인 컨트롤러(`make run`) 빌드 환경 (cmake, libtorch aarch64)
- [ ] sim2sim(`scripts/sim2sim/play_mujoco.py`) GUI 뷰어를 TX2에서 확인
- [ ] 디스크 확장 (eMMC 여유 약 6GB) — NVMe/SD 추가 후 Docker data-root 이전 권장
- [ ] RL 학습용 x86 + RTX PC에 Isaac Lab 환경 구성 → `.onnx`를 TX2로 배포

## 참고 링크
- Berkeley Humanoid Lite: https://github.com/HybridRobotics/berkeley-humanoid-lite
- Lowlevel: https://github.com/HybridRobotics/berkeley-humanoid-lite-lowlevel
- Assets: https://github.com/HybridRobotics/berkeley-humanoid-lite-assets
- MoveIt2 Humble 문서: https://moveit.picknik.ai/humble/
- ROS2 Humble 문서: https://docs.ros.org/en/humble/
