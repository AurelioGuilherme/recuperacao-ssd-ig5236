#!/usr/bin/env bash
# Instala as dependencias (Ubuntu/Debian). Em outras distribuicoes, instale os equivalentes.
source "$(dirname "$0")/_common.sh"
command -v apt-get >/dev/null || die "Este script usa apt-get (Ubuntu/Debian). Instale manualmente: git python3 pciutils nvme-cli smartmontools f3 parted e2fsprogs unrar"
info "Vai instalar: git python3 pciutils nvme-cli smartmontools f3 parted e2fsprogs p7zip-full unrar"
sudo apt-get update
sudo apt-get install -y git python3 pciutils nvme-cli smartmontools f3 parted e2fsprogs p7zip-full
if ! sudo apt-get install -y unrar; then
    aviso "Pacote 'unrar' indisponivel. No Ubuntu ele fica no repositorio 'multiverse':"
    aviso "  sudo add-apt-repository multiverse && sudo apt-get update && sudo apt-get install unrar"
    aviso "No Debian, fica em 'non-free'. NAO use 7z para extrair o firmware: ele falha com 'Unsupported Method'."
fi
ok "Dependencias instaladas (confira os avisos acima)."
