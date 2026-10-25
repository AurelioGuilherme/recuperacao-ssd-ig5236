#!/usr/bin/env bash
# Teste de integridade com F3 (f3write/f3read). APAGA o dispositivo informado (cria GPT + ext4 de teste).
# Uso: 08-teste-f3.sh /dev/nvme0n1 [rapido|completo]     (rapido = 100 GB, completo = disco todo)
source "$(dirname "$0")/_common.sh"
DEVICE="${1:-}"; MODO="${2:-rapido}"
[ -b "$DEVICE" ] || die "Uso: $0 /dev/nvmeXn1 [rapido|completo]"
[ "$(lsblk -dn -o TYPE "$DEVICE")" = "disk" ] || die "$DEVICE nao e um disco inteiro."
command -v f3write >/dev/null || die "f3 nao instalado (scripts/linux/00-instalar-dependencias.sh)."

# Seguranca 1: nada montado
lsblk -nr -o MOUNTPOINTS "$DEVICE" | grep -q . && die "$DEVICE tem particoes montadas. Abortando."
# Seguranca 2: nao pode ser o disco que contem /
ROOT_SRC="$(findmnt -n -o SOURCE /)"
ROOT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -1)"
[ "$ROOT_DISK" != "$DEVICE" ] || die "$DEVICE e o disco do sistema. Abortando."

lsblk -o NAME,MODEL,SIZE,TYPE "$DEVICE"
confirma "ISTO VAI APAGAR TUDO EM $DEVICE (cria uma tabela GPT e uma particao ext4 de teste)." "$DEVICE"

sudo parted -s "$DEVICE" mklabel gpt mkpart primary ext4 1MiB 100%
sudo partprobe "$DEVICE"; sudo udevadm settle; sleep 1
if [[ "$DEVICE" =~ [0-9]$ ]]; then PART="${DEVICE}p1"; else PART="${DEVICE}1"; fi
[ -b "$PART" ] || die "Particao $PART nao apareceu."
sudo mkfs.ext4 -F -L teste-f3 "$PART"
MNT="$(sudo mktemp -d /mnt/f3.XXXXXX)"
sudo mount "$PART" "$MNT"
sudo chown "$USER" "$MNT"
SRC="$(findmnt -n -o SOURCE "$MNT")"
[ "$SRC" = "$PART" ] || { sudo umount "$MNT"; die "O ponto de teste nao esta no $PART (esta em $SRC). Abortando para nao encher outro disco."; }
df -h "$MNT"

cleanup() { rm -f "$MNT"/*.h2w 2>/dev/null; sudo umount "$MNT" 2>/dev/null && sudo rmdir "$MNT" 2>/dev/null; }
trap cleanup EXIT
if [ "$MODO" = "completo" ]; then f3write "$MNT"; else f3write "$MNT" --end-at=100; fi
f3read "$MNT" | tee "$LOG_DIR/f3-$(date +%Y%m%d-%H%M%S).txt"
echo
info "Esperado: 'Data LOST: 0.00 Byte' e Corrupted / Slightly changed / Overwritten todos em zero."
