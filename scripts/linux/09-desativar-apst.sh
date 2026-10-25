#!/usr/bin/env bash
# Adiciona nvme_core.default_ps_max_latency_us=0 ao GRUB (desliga o APST: economia de energia profunda
# do NVMe, que o autor do projeto upstream relata como instavel no IG5236). Ubuntu/Debian com GRUB.
source "$(dirname "$0")/_common.sh"
F=/etc/default/grub
[ -f "$F" ] || die "$F nao existe. Seu sistema nao usa GRUB nesse caminho: adicione o parametro ao seu bootloader manualmente."
if grep -q 'nvme_core.default_ps_max_latency_us' "$F"; then
    ok "O parametro ja esta em $F."; exit 0
fi
confirma "Vou fazer backup de $F e adicionar nvme_core.default_ps_max_latency_us=0 em GRUB_CMDLINE_LINUX_DEFAULT." "OK"
sudo cp "$F" "$F.bak.$(date +%Y%m%d%H%M%S)"
sudo sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 nvme_core.default_ps_max_latency_us=0"/' "$F"
grep '^GRUB_CMDLINE_LINUX_DEFAULT' "$F"
if command -v update-grub >/dev/null; then sudo update-grub; else aviso "update-grub nao encontrado; rode o equivalente da sua distro (grub2-mkconfig...)."; fi
ok "Pronto. Reinicie e confira: cat /proc/cmdline ; cat /sys/module/nvme_core/parameters/default_ps_max_latency_us  (deve dar 0)"
