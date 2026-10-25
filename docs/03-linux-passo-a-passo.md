# 03 — Linux, passo a passo (método testado)

Todos os comandos abaixo são rodados **na raiz do repositório**. Cada passo tem o script correspondente em `scripts/linux/`.

> Este é o único caminho que **testamos de ponta a ponta**. Sistema usado: Ubuntu 24.04, kernel 6.8.0, Python 3.12, placa AMD X370, SSD no slot M.2 (link Gen3 x4), sistema operacional num SSD SATA separado.

## Visão geral

```
[Preparar] 00 dependências → 01 upstream → 02 firmware → 03 diagnóstico
[Isolar]   04 preparar-vfio → 05 check
[Gravar]   06 run   (loader → programmer → mpinfo/NAND → etapa destrutiva)
[Ativar]   desligar tudo, cortar a energia 30 s, ligar
[Conferir] 07 verificar → 08 teste F3 → 09 desativar APST
```

## Passo 0 — Pré-requisitos

1. O sistema Linux roda de **outro disco** (ou de um pendrive Live). O SSD com problema não pode ter nada montado.
2. **IOMMU ligado na BIOS.** AMD: `IOMMU`/`AMD-Vi` (e `SVM`). Intel: `VT-d`. Sem isso, o passo 05 falha.
3. Kernel ≥ 6.6:
   ```bash
   uname -r
   ```
4. O PC fica na tomada. Desative a suspensão automática enquanto durar o procedimento.

## Passo 1 — Obter este repositório

```bash
git clone https://github.com/AurelioGuilherme/recuperacao-ssd-ig5236 recuperacao-ssd-ig5236
cd recuperacao-ssd-ig5236
chmod +x scripts/linux/*.sh
```

## Passo 2 — Dependências

```bash
./scripts/linux/00-instalar-dependencias.sh
```

Instala `git python3 pciutils nvme-cli smartmontools f3 parted e2fsprogs p7zip-full unrar`. Se o `unrar` não existir no seu repositório de pacotes (Ubuntu: `multiverse`; Debian: `non-free`), o script avisa como habilitar.

## Passo 3 — Baixar o código upstream

```bash
./scripts/linux/01-baixar-upstream.sh
```

Clona `Egorich-print/netac-nv7000-recovery` (licença MIT) em `vendor/` e registra o commit em `logs/upstream-commit.txt`. Nossa ferramenta (`tools/guided_flash.py`) importa o `netac_pipeline.py` dele, que implementa o acesso direto ao controlador. **Não atualize esse clone** (`git pull`) durante o procedimento.

## Passo 4 — Firmware

Siga [`02-obter-firmware.md`](02-obter-firmware.md) e termine com:

```bash
./scripts/linux/02-extrair-firmware-3SJ11.sh ~/Downloads/netac_3.S.J.11_external.rar
python3 tools/verificar_firmware.py     # precisa dizer TUDO CONFERE
```

## Passo 5 — Diagnóstico

```bash
./scripts/linux/03-diagnostico.sh
```

Confira no relatório: ID `1dbe:5636`, `MN-5236`, `2.0.0.3`, ~2 GB, `/dev/iommu` presente, `CONFIG_VFIO_DEVICE_CDEV=y`, grupos de IOMMU > 0. Se o `/dev/iommu` não existir, rode `sudo modprobe iommufd` e repita.

## Passo 6 — Dissipador e ambiente

Se você abriu o SSD para ler a NAND, **recoloque o dissipador e as almofadas térmicas** (ou aponte um ventilador para o SSD) antes de gravar. O autor do projeto upstream mediu 51 °C sob escrita contínua *com* dissipador; sem ele, é mais.

## Passo 7 — Isolar o SSD do driver do kernel

```bash
./scripts/linux/04-preparar-vfio.sh
```

O que faz: detecta o dispositivo InnoGrit, **recusa se houver partições montadas**, carrega o `vfio-pci`, desliga o `D3cold` e o autosuspend, solta o SSD do driver `nvme` (sem descarregar o módulo) e liga ao `vfio-pci`.

Esperado no fim: `Ligado ao vfio-pci. cdev: /dev/vfio/devices/vfio0`. **O SSD deixa de aparecer como `/dev/nvmeXnY`** até o `desfazer-vfio.sh` ou um reinício. Isso é normal.

> Depois do passo 7 **não deixe o PC parado**. O dispositivo pode cair em estado de baixo consumo e ficar inacessível (veja [`08-solucao-de-problemas.md`](08-solucao-de-problemas.md)). Siga direto para os passos 8 e 9.

## Passo 8 — Check (somente leitura)

```bash
./scripts/linux/05-check.sh
```

Esperado:

```
OK            loader.fw
OK            programmer+cust+3SJ11+ymtcx2.fw
OK            rdisk+cust+3SJ11+...+ymtcx2-cmfg.fw
estado inicial: CAP=0x00000020640100ff VS=0x00010200 CC=0x00000000 CSTS=0x00000000
[inicio] enable -> ready CSTS=0x00000001 em 0.5s
[inicio] SN='SSD-5236' MN='MN-5236' FR='2.0.0.3'

Modo check: nada foi gravado. ROM mode: True
```

- `CAP=0xffffffffffffffff` ou erro ao abrir o dispositivo → o SSD ficou inacessível. **Desligue o PC, corte a energia da fonte por 30 s**, volte e refaça do passo 7.
- Identidade diferente de `MN-5236` → **pare** e peça ajuda antes de rodar o `run`.

## Passo 9 — Run (grava o firmware)

Fique ao lado do PC. **Não** use Ctrl+C, **não** feche o terminal, **não** deixe suspender.

```bash
./scripts/linux/06-run.sh
```

O script mostra um aviso e pede `ESTOU PRONTO`. Depois ele abre o fluxo em Python, que tem **duas** confirmações:

### 9.1 Confirmação 1: `GRAVAR LOADER E PROGRAMMER`

O texto na tela explica que loader e programmer são confirmados **juntos**, porque o controlador volta ao ROM se ficar parado entre eles. Digite a frase para continuar. Em seguida, **sem digitar mais nada**, acontece:

1. `ToRecovery: 0` e o download do `loader.fw` (5 chunks), terminando em `FW Commit … status 0x0000`.
2. Uma linha como:
   ```
   [pos-loader] SEM mexer no CC: um unico Identify, esperando ate 150 s pela resposta...
   ```
   **Aqui o script espera**. No nosso disco, a resposta demorou **80,2 s**. Não é travamento. O script não toca no registrador `CC` de propósito (veja [`09-como-funciona.md`](09-como-funciona.md)). Você verá:
   ```
   [pos-loader] Identify sem tocar no CC -> status=0 apos 80.2s | ...
   [pos-loader] SN='SSD-5236' MN='MN-5236' FR='2.0.0.3'
   ```
3. A etapa 2 grava o programmer (153 chunks, ~1 s) e dá o commit. Em seguida, no nosso disco:
   ```
   [pos-programmer] Identify sem tocar no CC -> status=0 apos 12.6s | ...
   [pos-programmer] SN='SSD-DRAM-120216-V' MN='INNOGRIT' FR='3.S.J.11'
   ```
   Essa identidade (`INNOGRIT`, `3.S.J.11`) mostra que o programmer entrou.
4. Treino de DDR (`DDR eye: 0`) e leitura do `mpinfo`, com as entradas de NAND decodificadas.

### 9.2 Ponto de decisão: confira a NAND

Olhe a linha `fabricante:` do `mpinfo`. No nosso disco, 16 entradas `9bc529492000  fabricante: YMTC`.

- **`YMTC`** (código `9B`) e você está usando o pacote YMTC → pode continuar.
- **Qualquer outro fabricante** → **NÃO digite a próxima frase.** Você gravou um programmer para a NAND errada. Veja [`08-solucao-de-problemas.md`](08-solucao-de-problemas.md).
- **`mpinfo` zerado** ou "nenhuma entrada de NAND" → o offset de decodificação (que não verificamos) pode não servir ao seu disco. Decida com base na evidência física (marcação da NAND).

### 9.3 Confirmação 2: `APAGAR E GRAVAR RDISK` (sem volta)

Enquanto o script espera você digitar, ele envia um `mpinfo` (só leitura) a cada 3 s para manter o controlador ativo. Pode ler com calma. Quando digitar a frase, ele faz: `BrandNew`, `RemoveCheck`, grava o rdisk (888 832 bytes), grava a página CONF, dá o commit e finaliza com `SmartClean` e `BrandNew`. **Todos os dados do SSD são apagados.**

Saída esperada (resumida):

```
BrandNew: 0
RemoveCheck: 0
  [rdisk] download ok (888832 bytes)
CONF 0xE5: 0
commit 0x19 -> 0
...
IDENT FINAL: ('SSD-DRAM-120216-V', 'INNOGRIT', '3.S.J.11')

FIM. AGORA: desligue o PC e corte a energia (chave da fonte) por ~30 s. Reiniciar NAO basta.
Processo mantido ABERTO. ...
```

**Nesse ponto a identidade ainda é a do programmer. Isso é esperado.** O rdisk só ativa com o corte de energia. Só agora aperte Enter para encerrar.

### Se o script entrar em `hold`

Se aparecer `FALHOU …` seguido de "Processo mantido ABERTO", **não aperte Enter ainda**. Abra um segundo terminal e rode:

```bash
lspci -nn -s $(lspci -D -d 1dbe: | awk '{print $1}')
sudo dmesg | tail -15
```

Guarde esses resultados e o log (`logs/run-*.log`), e veja [`08-solucao-de-problemas.md`](08-solucao-de-problemas.md). Só então aperte Enter.

## Passo 10 — Cortar a energia (obrigatório)

Reiniciar **não basta**: o firmware de runtime só ativa depois de um corte total de energia.

1. Desligue o PC pelo sistema.
2. Desligue a chave da fonte (ou tire o cabo da tomada).
3. Com o PC desligado, segure o botão power por uns 10 s (descarrega a energia residual).
4. Espere pelo menos 30 s. Um minuto é melhor.
5. Religue.

## Passo 11 — Conferir

```bash
./scripts/linux/07-verificar-pos-power-cycle.sh
```

Resultado esperado (o que vimos):

```
lspci:      1dbe:5236 "NVMe SSD Controller IG5236"
nvme list:  SSD-DRAM-120216-F   INNOGRIT   2.00 TB   512 B   3.S.J.11
lsblk:      nvme0n1  1,8T
dmesg:      32/0/0 default/read/poll queues ; "Ignoring bogus Namespace Identifiers"
SMART:      critical_warning 0 ; media_errors 0 ; num_err_log_entries 0
```

A mensagem "Ignoring bogus Namespace Identifiers" é normal para esse controlador.

Se continuar como `MN-5236`/2 GB: o corte de energia não foi completo, ou o rdisk não ficou. Faça o corte de novo com calma. Se persistir, veja [`08-solucao-de-problemas.md`](08-solucao-de-problemas.md).

## Passo 12 — Antes de confiar no disco

Siga [`06-pos-recuperacao.md`](06-pos-recuperacao.md): teste F3, APST, dissipador e backup.

## Voltar atrás

Se você preparou o SSD para o VFIO e decidiu **não** gravar:

```bash
./scripts/linux/desfazer-vfio.sh
```

Isso devolve o SSD ao driver `nvme`. Nada foi gravado nele se você só rodou `04` e `05`.
