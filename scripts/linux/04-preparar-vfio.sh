#!/usr/bin/env bash
# Tira o SSD do driver nvme do kernel e liga ao vfio-pci, mantendo o dispositivo em D0.
# O SSD DEIXA DE APARECER como /dev/nvmeX ate rodar desfazer-vfio.sh (ou reiniciar).
source "$(dirname "$0")/_common.sh"
detecta_dev
info "Dispositivo: $DEV (ID $ID) | ponte/porta: $PORT"
if [ "$ID" != "1dbe:5636" ]; then
    aviso "O ID e $ID. O ROM mode visto ate hoje e 1dbe:5636. Se for 1dbe:5236, o disco provavelmente JA esta com firmware completo."
    confirma "Continuar mesmo assim?" "CONTINUAR"
fi

# Seguranca: nunca mexer num disco montado ou que contenha o sistema
CTRL="$(ls "/sys/bus/pci/devices/$DEV/nvme" 2>/dev/null | head -1 || true)"
if [ -n "$CTRL" ]; then
    for blk in /dev/${CTRL}n*; do
        [ -b "$blk" ] || continue
        if lsblk -nr -o MOUNTPOINTS "$blk" | grep -q .; then
            die "$blk tem particoes MONTADAS. Este e o disco do sistema ou esta em uso. Abortando."
        fi
    done
fi
info "Nenhuma particao montada nesse dispositivo."

sudo modprobe vfio-pci || die "Nao consegui carregar vfio-pci."
[ -e /sys/module/vfio_pci/parameters/disable_idle_d3 ] && echo Y | sudo tee /sys/module/vfio_pci/parameters/disable_idle_d3 >/dev/null
for d in "$PORT" "$DEV"; do
    echo 0  | sudo tee "/sys/bus/pci/devices/$d/d3cold_allowed"  >/dev/null 2>&1 || true
    echo on | sudo tee "/sys/bus/pci/devices/$d/power/control"   >/dev/null 2>&1 || true
done
if [ -e "/sys/bus/pci/devices/$DEV/driver" ]; then
    DRV="$(basename "$(readlink "/sys/bus/pci/devices/$DEV/driver")")"
    info "Soltando $DEV do driver $DRV (sem descarregar o modulo, que pode estar 'em uso')."
    echo "$DEV" | sudo tee "/sys/bus/pci/drivers/$DRV/unbind" >/dev/null
fi
echo vfio-pci | sudo tee "/sys/bus/pci/devices/$DEV/driver_override" >/dev/null
echo "$DEV" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind >/dev/null || die "bind ao vfio-pci falhou."
sleep 1
acha_cdev
ok "Ligado ao vfio-pci. cdev: $CDEV | power_state: $(cat /sys/bus/pci/devices/$DEV/power_state)"
info "Proximo passo: scripts/linux/05-check.sh"
