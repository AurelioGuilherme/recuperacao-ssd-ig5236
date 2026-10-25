# 08 — Solução de problemas

Todos os itens abaixo aconteceram de verdade durante os nossos testes (ou são avisos das fontes citadas). A regra geral:

> **Se algo falhou, não repita o mesmo passo às cegas.** Guarde o log (`logs/`), faça o diagnóstico em outro terminal e só então decida. Em todos os casos que vimos, **um corte total de energia devolveu o SSD ao ROM mode, sem perda adicional**.

## Corte total de energia (o "reset" universal)

1. Desligue o PC pelo sistema.
2. Desligue a chave da fonte (ou tire da tomada).
3. Segure o botão power uns 10 s com o PC desligado.
4. Espere 30 s ou mais.
5. Ligue. Refaça do passo 7 do [`03`](03-linux-passo-a-passo.md) (o reboot desfaz a ligação ao `vfio-pci`).

**Reiniciar pelo sistema não equivale a isso.**

## Tabela de sintomas

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `FileNotFoundError: /dev/vfio/devices/vfio0` / `ls /dev/vfio/devices/` vazio | O SSD não está ligado ao `vfio-pci` (o `nvme` ainda o segura) | Rode `04-preparar-vfio.sh` (ele solta o SSD do `nvme` sem descarregar o módulo) |
| `modprobe: FATAL: Module nvme is in use` | Normal: outro NVMe (ou o sistema) usa o módulo | Não descarregue o módulo; o `04` usa `unbind` só no seu SSD |
| `tee: .../vfio-pci/bind: Dispositivo ou recurso está ocupado` | O SSD ainda estava ligado ao `nvme` | Faça o `unbind` antes (o `04` faz) |
| `/dev/iommu` não existe | Módulo `iommufd` não carregado | `sudo modprobe iommufd` |
| Nenhum grupo em `/sys/kernel/iommu_groups`, ou `/sys/class/iommu` vazio | IOMMU desligado na BIOS | Ative AMD-Vi/IOMMU/SVM (AMD) ou VT-d (Intel) |
| `CONFIG_VFIO_DEVICE_CDEV` ausente | Kernel antigo (< 6.6) | Atualize o kernel |
| `unrar`/`7z`: `Unsupported Method`; `.fw` de 0 bytes; hash `e3b0c442…b855` | O 7-Zip antigo não suporta o RAR5 do pacote | Use `unrar` (ou WinRAR). Apague os arquivos vazios |
| `HASH DIFERENTE` / `FALTANDO` na verificação | Arquivo errado, corrompido ou extração falha | **Não prossiga.** Refaça o download e a extração |
| `BAR0 ja le 0xFFFF...` / `OSError: [Errno 22] Invalid argument` ao abrir o dispositivo / `power_state: D3cold` / `dmesg`: `Unable to change power state ... device inaccessible`, `Invalid PCI ROM header signature ... got 0xffff` | O dispositivo ficou inacessível: ficou **ocioso** depois do `04`, ou o processo que o segurava terminou | **Corte total de energia** e refaça do `04`. **Não use `remove`/`rescan`** (o upstream avisa que isso, com o dispositivo em D3cold, o faz sumir do barramento e pode travar a máquina) |
| `[pos-loader] ... Identify` → `TIMEOUT` (em versões antigas do script), ou "sem identidade depois do loader" | O loader leva **~80 s** para responder; mexer no `CC` (desligar/religar o controlador) nesse intervalo o derruba de volta ao ROM | O script atual espera até 150 s **sem tocar no `CC`**. Se ainda assim não responder, deixe no `hold`, rode `lspci`/`dmesg` e faça o corte de energia |
| Programmer: `fw chunk #N FAILED status=None (CSTS=00000000)` | O controlador se reiniciou durante o download (voltou ao ROM) | Corte de energia. Não pause entre loader e programmer; use o `06-run.sh` (uma única confirmação) |
| O script entrou em `hold` ("Processo mantido ABERTO") | Uma etapa falhou | **Não aperte Enter ainda.** Em outro terminal: `lspci -nn -d 1dbe:`, `cat /sys/bus/pci/devices/<DEV>/power_state`, `sudo dmesg \| tail -15`. Guarde o log. Depois Enter e corte de energia |
| Depois do corte de energia, continua `MN-5236`/2 GB | A energia não foi cortada de verdade (a fonte mantém standby), ou o rdisk não ficou | Repita o corte: fonte desligada **e** botão power 10 s, 30 s de espera. Se persistir, revise o `run-*.log` (o `commit 0x19` deve ter dado 0) |
| Depois do corte de energia, o SSD sumiu do `lspci` | Hardware, slot, ou gravação com pacote errado | **Pare.** Veja a seção abaixo |
| O `mpinfo` pós-loader vem **zerado** | Normal: o controlador não informa a NAND antes do programmer | Veja o `mpinfo` depois do programmer |
| `mpinfo` depois do programmer mostra "nenhuma entrada de NAND" | O offset de decodificação (`0x24E`) vem de outro projeto e **não foi verificado** | Use a evidência física (marcação da NAND) para decidir |
| `mpinfo` mostra fabricante **diferente** do esperado | Você gravou o programmer para a NAND errada | **Não digite `APAGAR E GRAVAR RDISK`.** Corte a energia e escolha o pacote certo. O disco pode ou não voltar ao ROM |
| `dmesg: leitura de buffer de kernel falhou: Operação não permitida` | `dmesg` exige root | Use `sudo dmesg` |
| `vfio_pci: unknown parameter 'iommufd' ignored` | Parâmetro extra num `modprobe` antigo | Inofensivo |
| `nvme set-feature -f 0x0c -v 0` → `Invalid Field in Command` | O comando não enviava a tabela que o APST exige | Inofensivo; use o parâmetro do kernel (`09-desativar-apst.sh`) |
| `f3write`: `Free space: 78 GB`, `Permission denied` | O ponto de montagem **não** é o NVMe (ficou no disco do sistema) | **Não rode o `f3write`.** Ele encheria o disco do sistema. Use o `08-teste-f3.sh`, que confere isso |
| `Nao consegui importar netac_pipeline` | O upstream não foi baixado | `01-baixar-upstream.sh` |
| `O netac_pipeline.py do upstream nao tem '...'` | O upstream mudou | `git -C vendor/netac-nv7000-recovery checkout <commit de logs/upstream-commit.txt>` |
| Download do usbdev.ru dá `HTTP 500` / "Temporary problems with downloading files" | Problema do servidor (afetou todos os arquivos quando testamos) | Tente depois; avise o administrador; veja [`02`](02-obter-firmware.md) |

## Se o SSD sumiu do barramento

Se, depois de uma gravação, o SSD **não aparece mais** no `lspci` (nem depois de cortes de energia), pode ter acontecido o que um usuário relatou ao gravar um pacote errado. O que existe:

1. **Garantia**, se ainda valer.
2. **Laboratório de recuperação**, perguntando se atendem IG5236 em ROM mode.
3. **O ROM jumper** descrito por usuários de fórum (curto de dois pontos de teste). **Não ensinamos isso**: veja os motivos em [`04-windows-mputility.md`](04-windows-mputility.md#se-o-disco-sumiu-do-barramento).

## Pedindo ajuda

Abra uma *issue* com o modelo resumido em [`10-relatar-resultado.md`](10-relatar-resultado.md): saída do `03-diagnostico.sh`, o log completo, o PN do adesivo e a NAND. **Remova o número de série** de fotos e logs se não quiser expô-lo.
