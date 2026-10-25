#!/usr/bin/env bash
# Funcoes comuns. Nao execute diretamente; os outros scripts fazem "source" deste arquivo.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FW_DIR="${NETAC_FW_DIR:-$ROOT/firmware}"
UPSTREAM="${NETAC_UPSTREAM:-$ROOT/vendor/netac-nv7000-recovery}"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

info()  { printf '\033[1;34m[info]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[ ok ]\033[0m %s\n' "$*"; }
aviso() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }
erro()  { printf '\033[1;31m[erro]\033[0m %s\n' "$*" >&2; }
die()   { erro "$*"; exit 1; }

confirma() {  # confirma "texto" "FRASE"  -> pede para digitar a FRASE exata
    printf '\n%s\n' "$1"
    read -r -p "Digite exatamente $2 para continuar (Enter cancela): " resp
    [ "$resp" = "$2" ] || { echo "Cancelado."; exit 0; }
}

# Detecta o dispositivo InnoGrit (vendor 1dbe). Define DEV, PORT e ID.
detecta_dev() {
    if [ -n "${NETAC_DEV:-}" ]; then
        DEV="$NETAC_DEV"
    else
        mapfile -t L < <(lspci -D -d 1dbe: 2>/dev/null | awk '{print $1}')
        [ "${#L[@]}" -ge 1 ] || die "Nenhum dispositivo InnoGrit (vendor 1dbe) encontrado. Veja: lspci -nn | grep -i innogrit"
        [ "${#L[@]}" -eq 1 ] || die "Mais de um dispositivo InnoGrit: ${L[*]}. Defina NETAC_DEV=<endereco PCI>."
        DEV="${L[0]}"
    fi
    [ -e "/sys/bus/pci/devices/$DEV" ] || die "Dispositivo $DEV nao existe em /sys/bus/pci/devices."
    PORT="$(basename "$(dirname "$(readlink -f "/sys/bus/pci/devices/$DEV")")")"
    ID="$(lspci -n -s "$DEV" | awk '{print $3}')"
}

# Descobre o /dev/vfio/devices/vfioN do dispositivo (precisa estar ligado ao vfio-pci).
acha_cdev() {
    [ -d "/sys/bus/pci/devices/$DEV/vfio-dev" ] || die "$DEV nao esta ligado ao vfio-pci. Rode scripts/linux/04-preparar-vfio.sh"
    VF="$(ls "/sys/bus/pci/devices/$DEV/vfio-dev" | head -1)"
    CDEV="/dev/vfio/devices/$VF"
    [ -e "$CDEV" ] || die "$CDEV nao existe."
}
