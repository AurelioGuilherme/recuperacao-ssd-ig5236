# firmware/

Esta pasta guarda o **descritor** do pacote de firmware (`pacote-3SJ11.json`) e, depois que você extrair, os arquivos `.fw` em `m2_0536/`.

**Os arquivos `.fw` não são distribuídos neste repositório** (pertencem aos titulares, e o `.gitignore` os exclui). Veja [`../docs/02-obter-firmware.md`](../docs/02-obter-firmware.md).

Estrutura esperada, depois de `scripts/linux/02-extrair-firmware-3SJ11.sh`:

```
firmware/
├── pacote-3SJ11.json
└── m2_0536/
    ├── loader.fw                                   (20 480 bytes)
    ├── programmer+cust+3SJ11+ymtcx2.fw             (626 688 bytes)
    └── rdisk+cust+3SJ11+512b+hcrc+semi+l0ps+iecc+semiswitch+logerr+rel+mstripe+raid+a1perf_raid+ymtcx2-cmfg.fw   (888 832 bytes)
```

Conferir:

```bash
python3 tools/verificar_firmware.py
```
