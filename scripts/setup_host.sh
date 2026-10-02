#!/bin/bash
# Jetson TX2 host setup: docker group, CAN tools/modules. Run once with sudo rights.
set -e

# 1) docker without sudo (re-login or `newgrp docker` afterwards)
sudo usermod -aG docker "$USER"

# 2) CAN utilities on the host
sudo apt-get update
sudo apt-get install -y can-utils net-tools

# 3) CAN kernel modules (gs_usb: USB-CAN adapters, mttcan: TX2 on-board CAN)
sudo modprobe can
sudo modprobe can_raw
sudo modprobe can_dev
sudo modprobe gs_usb
sudo modprobe mttcan || true

# load them on every boot
printf "can\ncan_raw\ncan_dev\ngs_usb\nmttcan\n" | sudo tee /etc/modules-load.d/can.conf >/dev/null

echo "Done. Log out and back in (or run 'newgrp docker') so the docker group applies."
