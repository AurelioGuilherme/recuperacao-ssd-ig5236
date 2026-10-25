#!/usr/bin/env bash
# Diagnostico SOMENTE LEITURA. Salva a saida em logs/diagnostico-<data>.txt
source "$(dirname "$0")/_common.sh"
OUT="$LOG_DIR/diagnostico-$(date +%Y%m%d-%H%M%S).txt"
{
echo "=== data ==="; date
echo "=== kernel ==="; uname -r
echo "=== python ==="; python3 --version
echo "=== PCI (InnoGrit 1dbe) ==="; lspci -nn -d 1dbe: || true
echo "=== PCI com driver ==="; lspci -k -d 1dbe: || true
echo "=== nvme list ==="; sudo nvme list || true
echo "=== lsblk ==="; lsblk -o NAME,MODEL,SIZE,TYPE,MOUNTPOINTS
echo "=== power_state ==="
for d in $(lspci -D -d 1dbe: | awk '{print $1}'); do echo "$d: $(cat /sys/bus/pci/devices/$d/power_state 2>/dev/null)"; done
echo "=== IOMMU ==="
ls /sys/class/iommu 2>/dev/null || echo "(sem /sys/class/iommu: IOMMU provavelmente desligado na BIOS)"
echo "grupos: $(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l)"
echo "=== VFIO cdev / iommufd no kernel ==="
grep -E "CONFIG_VFIO_DEVICE_CDEV|CONFIG_IOMMUFD=|CONFIG_VFIO_PCI=" "/boot/config-$(uname -r)" 2>/dev/null || echo "(sem /boot/config-$(uname -r))"
sudo modprobe iommufd 2>/dev/null && ls -l /dev/iommu 2>/dev/null || echo "/dev/iommu ausente"
echo "=== cmdline ==="; cat /proc/cmdline
echo "=== dmesg (nvme / InnoGrit) ==="; sudo dmesg 2>/dev/null | grep -i -E "nvme|1dbe" | tail -20
} 2>&1 | tee "$OUT"
echo
ok "Salvo em $OUT"
echo "Procure: ID 1dbe:5636, modelo MN-5236, ~2 GB e FW 2.0.0.3 = ROM mode (e o caso deste guia)."
