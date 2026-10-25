#!/usr/bin/env bash
# Rode DEPOIS de desligar o PC, cortar a energia (chave da fonte) por ~30 s e ligar de novo. So leitura.
source "$(dirname "$0")/_common.sh"
OUT="$LOG_DIR/pos-recuperacao-$(date +%Y%m%d-%H%M%S).txt"
{
echo "=== lspci ==="; lspci -nn -d 1dbe:
echo "=== nvme list ==="; sudo nvme list
echo "=== lsblk ==="; lsblk -o NAME,MODEL,SIZE,TYPE,MOUNTPOINTS
echo "=== SMART ==="
for n in /dev/nvme[0-9]; do
  [ -e "$n" ] || continue
  if sudo nvme id-ctrl "$n" 2>/dev/null | grep -q -i innogrit; then sudo nvme smart-log "$n"; fi
done
echo "=== dmesg ==="; sudo dmesg | grep -i -E "nvme|1dbe" | tail -15
} 2>&1 | tee "$OUT"
echo; ok "Salvo em $OUT"
echo "Sucesso = lspci com 1dbe:5236, modelo INNOGRIT, FW 3.S.J.11 e ~2,00 TB. Se ainda estiver MN-5236 / 2 GB, a energia nao foi cortada de verdade."
