#!/usr/bin/env bash
# Verifica hashes dos firmwares e le a identidade do SSD. NAO grava nada.
source "$(dirname "$0")/_common.sh"
detecta_dev
acha_cdev
LOG="$LOG_DIR/check-$(date +%Y%m%d-%H%M%S).log"
sudo env NETAC_FW_DIR="$FW_DIR" NETAC_UPSTREAM="$UPSTREAM" NETAC_CDEV="$CDEV" NETAC_QSIZE=2 \
    python3 -u "$ROOT/tools/guided_flash.py" check 2>&1 | tee "$LOG"
echo; info "Log: $LOG"
echo "Esperado: tres linhas OK, CAP=0x...20640100ff, enable -> ready e MN='MN-5236'."
echo "Se aparecer 'BAR0 ja le 0xFFFF...' ou erro ao abrir o dispositivo: desligue o PC, corte a energia por 30 s e refaca desde o passo 04."
