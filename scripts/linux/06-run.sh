#!/usr/bin/env bash
# Roda o fluxo completo (loader -> programmer -> etapa destrutiva), com confirmacoes.
source "$(dirname "$0")/_common.sh"
detecta_dev
acha_cdev
cat <<'AVISO'

ANTES DE CONTINUAR (leia):
  * TODOS OS DADOS DO SSD SERAO APAGADOS.
  * Fique ao lado do PC por ~10 minutos. NAO use Ctrl+C, NAO feche o terminal, NAO deixe o PC suspender.
  * Notebook: na tomada. Desktop: no-break se tiver.
  * Se o script entrar em "hold", NAO aperte Enter ainda: veja docs/08-solucao-de-problemas.md.
AVISO
confirma "Voce rodou o 05-check.sh e ele passou? O dissipador do SSD esta no lugar?" "ESTOU PRONTO"
LOG="$LOG_DIR/run-$(date +%Y%m%d-%H%M%S).log"
sudo env NETAC_FW_DIR="$FW_DIR" NETAC_UPSTREAM="$UPSTREAM" NETAC_CDEV="$CDEV" NETAC_QSIZE=2 \
    python3 -u "$ROOT/tools/guided_flash.py" run 2>&1 | tee "$LOG"
echo; info "Log: $LOG"
