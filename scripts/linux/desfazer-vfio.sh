#!/usr/bin/env bash
# Devolve o SSD ao driver nvme do kernel (o oposto do 04-preparar-vfio.sh).
# Nao rode isso no meio do 06-run.sh.
source "$(dirname "$0")/_common.sh"
detecta_dev
if [ -e "/sys/bus/pci/devices/$DEV/driver" ]; then
    DRV="$(basename "$(readlink "/sys/bus/pci/devices/$DEV/driver")")"
    echo "$DEV" | sudo tee "/sys/bus/pci/drivers/$DRV/unbind" >/dev/null
fi
echo "" | sudo tee "/sys/bus/pci/devices/$DEV/driver_override" >/dev/null
sudo modprobe nvme
echo "$DEV" | sudo tee /sys/bus/pci/drivers_probe >/dev/null
sleep 2
lspci -k -s "$DEV" | grep -i "driver in use" || aviso "Nenhum driver ligado ainda."
sudo nvme list
