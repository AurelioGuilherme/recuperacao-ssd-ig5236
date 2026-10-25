#!/usr/bin/env bash
# Extrai SOMENTE os 3 arquivos .fw do pacote netac_3.S.J.11_external.rar (nao extrai o .exe)
# para firmware/m2_0536/ e confere tamanhos e SHA-256.
source "$(dirname "$0")/_common.sh"
RAR="${1:-}"
[ -f "$RAR" ] || die "Uso: $0 /caminho/para/netac_3.S.J.11_external.rar"
command -v unrar >/dev/null || die "unrar nao encontrado. Rode scripts/linux/00-instalar-dependencias.sh (nao use 7z: 'Unsupported Method')."

TAM="$(stat -c %s "$RAR")"
[ "$TAM" -eq 51530689 ] || aviso "Tamanho $TAM difere dos 51530689 bytes esperados. Pode ser outro arquivo ou download corrompido."
info "SHA-256 do arquivo baixado (anote; o site de origem nao publica hash oficial):"
sha256sum "$RAR"
info "Testando integridade do RAR..."
unrar t "$RAR" | tail -3
unrar t "$RAR" >/dev/null || die "unrar t falhou: o arquivo esta corrompido. Baixe de novo."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
P="netac_3.S.J.11_external/m2_0536"
unrar x -idq "$RAR" "$P/loader.fw" "$P/programmer+cust+3SJ11+ymtcx2.fw" \
    "$P/rdisk+cust+3SJ11+512b+hcrc+semi+l0ps+iecc+semiswitch+logerr+rel+mstripe+raid+a1perf_raid+ymtcx2-cmfg.fw" "$TMP/" \
    || die "Falha ao extrair."
mkdir -p "$FW_DIR/m2_0536"
chmod u+w "$FW_DIR"/m2_0536/*.fw 2>/dev/null || true
cp "$TMP/$P/"*.fw "$FW_DIR/m2_0536/"
chmod a-w "$FW_DIR"/m2_0536/*.fw
ls -l "$FW_DIR/m2_0536/"
python3 "$ROOT/tools/verificar_firmware.py" "$FW_DIR/pacote-3SJ11.json"
