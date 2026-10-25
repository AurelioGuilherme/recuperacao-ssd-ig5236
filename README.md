# Recuperando um SSD InnoGrit IG5236 preso em "MN-5236 / 2 GB"

Guia **passo a passo, em português**, para tirar da condição de "disco morto" um SSD NVMe com controlador **InnoGrit IG5236** que passou a aparecer com **~2 GB** e o nome **`MN-5236`** (o *ROM mode*). Inclui o método **Linux** (testado de ponta a ponta) e o caminho **Windows** (solução da comunidade + como usar o método Linux a partir de um pendrive Live).

> ## ⚠️ Leia antes de qualquer comando
> - **Todos os dados do SSD são apagados.** Este procedimento não recupera dados.
> - Você grava firmware **direto no controlador**. Um pacote errado pode fazer o SSD **sumir do barramento**. Nesse caso a volta pode exigir mexer fisicamente na placa.
> - Os arquivos de firmware e o `MPUtility.exe` vêm de **sites de terceiros**, sem assinatura. Este repositório **não** os distribui.
> - Foi testado em **um único disco** (Netac NV7000 2 TB, NAND YMTC). O caminho Windows com MPUtility **não foi testado por nós**.
> - Se o SSD ainda está na **garantia**, use a garantia primeiro.
> - Material fornecido "como está", **por sua conta e risco**. Sem vínculo com Netac, InnoGrit ou os sites citados.

## Sumário

1. [O que é e para quem serve](#1-o-que-é-e-para-quem-serve)
2. [Estado de teste](#2-estado-de-teste)
3. [Qual caminho escolher](#3-qual-caminho-escolher)
4. [Estrutura do repositório](#4-estrutura-do-repositório)
5. [Pré-requisitos](#5-pré-requisitos)
6. [Início rápido — Linux](#6-início-rápido--linux)
7. [Windows](#7-windows)
8. [Arquivos de firmware (hashes)](#8-arquivos-de-firmware-hashes)
9. [Como funciona, em resumo](#9-como-funciona-em-resumo)
10. [Problemas mais comuns](#10-problemas-mais-comuns)
11. [Compatibilidade](#11-compatibilidade)
12. [Publicar este repositório do zero](#12-publicar-este-repositório-do-zero)
13. [Créditos e fontes](#13-créditos-e-fontes)
14. [Licença](#14-licença)

---

## 1. O que é e para quem serve

Alguns SSDs com o controlador **InnoGrit IG5236** (vendidos por Netac, ADATA, Fanxiang, Ant Esports e outras marcas) entram, após uma falha, em **ROM mode**: o controlador não consegue carregar o firmware guardado na NAND e responde com uma identidade mínima de fábrica. O sintoma é inconfundível:

| Onde | O que aparece em ROM mode |
|---|---|
| Linux, `lspci -nn` | `INNOGRIT … NVMe DC SSD IG5636 [1dbe:5636]` |
| Linux, `nvme list` | Modelo `MN-5236`, serial `SSD-5236`, firmware `2.0.0.3`, **2,15 GB** |
| Windows, Gerenciamento de Disco | Disco de **~2 GB**, "Não inicializado", nome `MN-5236` |
| Antes da falha | Travamentos em escrita pesada, erro de boot (`0xc000000e`) |

Este guia serve **se** o seu SSD tem esse sintoma **e** é um IG5236. Não serve para outros controladores, nem para SSDs que simplesmente não aparecem.

O que o procedimento faz: entrega ao controlador, pelo PCIe, três imagens em sequência (**loader → programmer → rdisk**), reinicializa o disco e, depois de um corte total de energia, ele volta com a capacidade real.

## 2. Estado de teste

| Item | Estado |
|---|---|
| Linux (método deste repositório) | ✅ **Testado em 1 disco**: Netac NV7000 2 TB, PN `NT01NV7000-2T0-E4X`, controlador `IG5236CAA`, NAND YMTC, pacote `3.S.J.11` |
| Ambiente do teste | Ubuntu 24.04, kernel 6.8.0, Python 3.12, placa AMD X370, SSD num slot M.2 Gen3 x4, sistema em SSD SATA separado |
| Teste de integridade (F3) | ✅ 100 GB e depois **1,70 TB** sem nenhum erro; SMART limpo |
| Windows + MPUtility | ⚠️ **Não testado por nós** (relatos de usuários em fórum) |
| Windows via pendrive Linux Live | ⚠️ Mesmo método do Linux; o pendrive Live em si **não foi testado** |
| Script `scripts/windows/diagnostico.ps1` | ⚠️ Não executado (somente leitura, revisado) |
| Outros pacotes de firmware (Micron B47R, SK hynix) | ❌ Não testados |
| Outras marcas/modelos com IG5236 | ❌ Não testados |
| Scripts `.sh` | Sintaxe verificada (`bash -n`); executados no fluxo real apenas nas partes descritas em `docs/exemplos/` |

## 3. Qual caminho escolher

```
Os dados no SSD são insubstituíveis? ── sim ──▶ PARE. Laboratório de recuperação (veja docs/00).
        │ não
        ▼
O SSD está na garantia? ── sim ──▶ Tente a garantia primeiro.
        │ não
        ▼
Você tem Linux (instalado em OUTRO disco)?
   ├─ sim ──▶ docs/03  (Linux — caminho testado)
   └─ não ──▶ Só Windows:
              ├─ Quer o caminho TESTADO ──▶ docs/05  (pendrive Linux Live)
              └─ Quer o caminho da comunidade ──▶ docs/04  (MPUtility, não testado por nós)
```

Em todos os casos, comece por [`docs/00`](docs/00-antes-de-comecar.md) e [`docs/01`](docs/01-diagnostico.md).

## 4. Estrutura do repositório

```
recuperacao-ssd-ig5236/
├── README.md                          ← este arquivo
├── LICENSE                            ← MIT (apenas para os arquivos deste repositório)
├── .gitignore                         ← exclui firmware, logs e o código de terceiros baixado
├── docs/
│   ├── 00-antes-de-comecar.md         ← riscos, perda de dados, o que você precisa
│   ├── 01-diagnostico.md              ← confirmar ROM mode; descobrir a NAND
│   ├── 02-obter-firmware.md           ← onde baixar, verificar e extrair
│   ├── 03-linux-passo-a-passo.md      ← o método testado, com saídas esperadas
│   ├── 04-windows-mputility.md        ← solução da comunidade (não testada por nós)
│   ├── 05-windows-via-linux-live.md   ← Windows usando o método Linux, via pendrive
│   ├── 06-pos-recuperacao.md          ← F3, APST, dissipador, backup
│   ├── 07-faq.md
│   ├── 08-solucao-de-problemas.md     ← sintomas reais → o que fazer
│   ├── 09-como-funciona.md            ← técnico: linha do tempo, comandos, lições
│   ├── 10-relatar-resultado.md        ← modelo para relatar o seu caso
│   └── exemplos/                      ← saídas reais (check, run, pós-recuperação)
├── firmware/
│   ├── LEIAME.md
│   ├── pacote-3SJ11.json              ← nomes, tamanhos e SHA-256 do pacote testado
│   └── m2_0536/                       ← você coloca os 3 .fw aqui (não versionados)
├── scripts/
│   ├── linux/
│   │   ├── _common.sh                 ← funções compartilhadas
│   │   ├── 00-instalar-dependencias.sh
│   │   ├── 01-baixar-upstream.sh
│   │   ├── 02-extrair-firmware-3SJ11.sh
│   │   ├── 03-diagnostico.sh          ← somente leitura
│   │   ├── 04-preparar-vfio.sh        ← isola o SSD do driver nvme
│   │   ├── 05-check.sh                ← somente leitura: hashes + identidade
│   │   ├── 06-run.sh                  ← grava (com confirmações)
│   │   ├── 07-verificar-pos-power-cycle.sh
│   │   ├── 08-teste-f3.sh             ← APAGA o disco indicado (teste de integridade)
│   │   ├── 09-desativar-apst.sh
│   │   └── desfazer-vfio.sh           ← devolve o SSD ao driver nvme
│   └── windows/
│       └── diagnostico.ps1            ← somente leitura
├── tools/
│   ├── guided_flash.py                ← fluxo guiado em um único processo (usa o upstream)
│   └── verificar_firmware.py          ← confere tamanho e SHA-256 dos .fw
├── vendor/                            ← o script 01 clona aqui o projeto upstream (MIT)
└── logs/                              ← seus logs (não versionados)
```

## 5. Pré-requisitos

| Item | Detalhe |
|---|---|
| SSD | Instalado num **slot M.2 (ou adaptador PCIe)**. **Adaptador USB-NVMe não serve** para o método Linux |
| Outro disco | O sistema Linux roda de **outro disco** (SATA, outro NVMe) ou de um **pendrive Live**. O SSD a recuperar **não pode** estar montado |
| Linux | Kernel **≥ 6.6** (VFIO cdev + iommufd). Testado: Ubuntu 24.04 / 6.8 |
| BIOS | **IOMMU ligado** (AMD-Vi/IOMMU + SVM, ou Intel VT-d) |
| Pacotes | `git python3 pciutils nvme-cli smartmontools f3 parted e2fsprogs unrar` (o `00-instalar-dependencias.sh` instala) |
| Firmware | Pacote correto para a **NAND** do seu SSD ([`docs/02`](docs/02-obter-firmware.md)) |
| Energia | PC na tomada, sem suspensão automática, ~15 minutos sem mexer |
| Físico | Chave de fenda; álcool isopropílico e pano sem fiapos (para ler a NAND, se necessário) |

## 6. Início rápido — Linux

> Este resumo existe para você ter uma visão do todo. **Leia [`docs/03`](docs/03-linux-passo-a-passo.md) antes de rodar**: ele explica cada saída e cada ponto de decisão.

```bash
# 0) clonar este repositório
git clone https://github.com/AurelioGuilherme/recuperacao-ssd-ig5236 recuperacao-ssd-ig5236
cd recuperacao-ssd-ig5236
chmod +x scripts/linux/*.sh

# 1) dependências e o projeto upstream (MIT) que usamos como biblioteca
./scripts/linux/00-instalar-dependencias.sh
./scripts/linux/01-baixar-upstream.sh

# 2) firmware: baixe o pacote (docs/02) e extraia só os 3 .fw
./scripts/linux/02-extrair-firmware-3SJ11.sh ~/Downloads/netac_3.S.J.11_external.rar
python3 tools/verificar_firmware.py          # precisa dizer: TUDO CONFERE

# 3) diagnóstico (somente leitura)
./scripts/linux/03-diagnostico.sh            # confirme 1dbe:5636 / MN-5236 / ~2 GB

# 4) dissipador no lugar; PC na tomada; sem suspensão
# 5) isolar o SSD do driver do kernel e verificar (NÃO deixe o PC parado depois disto)
./scripts/linux/04-preparar-vfio.sh
./scripts/linux/05-check.sh                  # somente leitura

# 6) gravar: fique ao lado do PC, sem Ctrl+C
./scripts/linux/06-run.sh
#    confirmação 1:  GRAVAR LOADER E PROGRAMMER
#    (espera ~80 s sem tocar em nada; depois programmer; depois o mpinfo)
#    confira: fabricante YMTC (0x9B) no mpinfo
#    confirmação 2:  APAGAR E GRAVAR RDISK   (sem volta)

# 7) CORTE TOTAL DE ENERGIA: desligar, chave da fonte off, botão power 10 s, esperar 30 s
# 8) conferir e testar
./scripts/linux/07-verificar-pos-power-cycle.sh
./scripts/linux/08-teste-f3.sh /dev/nvme0n1 rapido     # APAGA o disco indicado
./scripts/linux/09-desativar-apst.sh && sudo reboot
```

Resultado esperado depois do passo 7 (o que vimos): `lspci` com `1dbe:5236`, modelo `INNOGRIT`, **2,00 TB**, firmware `3.S.J.11`. Saídas completas em [`docs/exemplos/`](docs/exemplos/).

### As travas de segurança que os scripts têm

- `04` **recusa** se o dispositivo tiver partições montadas.
- `05`/`06` conferem o **SHA-256** dos três arquivos antes de falar com o SSD.
- `06` exige digitar frases exatas antes de cada etapa que grava; a etapa destrutiva é **separada** e vem depois da leitura da NAND.
- Se algo falha, o script entra em **`hold`** (mantém o dispositivo aberto) em vez de sair.
- `08` recusa discos montados e o disco do sistema, e só continua se você digitar o caminho do dispositivo.

## 7. Windows

Há **dois** caminhos. Nenhum depende de portar o script para Windows (veja o motivo em [`docs/05`](docs/05-windows-via-linux-live.md#por-que-não-portamos-o-script-para-windows)).

| Caminho | Estado | Quando usar | Guia |
|---|---|---|---|
| **A. Pendrive Linux Live** | Mesmo método do Linux (testado); o Live em si não foi testado | Você só tem Windows e quer o método que **testamos** | [`docs/05`](docs/05-windows-via-linux-live.md) |
| **B. MPUtility (comunidade)** | **Não testado por nós** | Você prefere a ferramenta gráfica relatada por vários usuários | [`docs/04`](docs/04-windows-mputility.md) |

Para **diagnosticar** no Windows (somente leitura), em PowerShell como Administrador, na pasta do repositório:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows\diagnostico.ps1
```

## 8. Arquivos de firmware (hashes)

Pacote testado: `netac_3.S.J.11_external.rar` (**51 530 689 bytes**), tag `InnoGrit IG5236 MPutility v1.0.0.103 [YMTC_TAS-3.S.J.11]`.

| Arquivo | Tamanho | SHA-256 |
|---|---|---|
| `netac_3.S.J.11_external.rar` (nossa cópia) | 51 530 689 | `fc0f74f46aba91874b574f9c42d8abb7bf9c19d039e68a74a015df85d1d71b3c` |
| `loader.fw` | 20 480 | `94fde6004d6ba0b0b2d149731735b5385ee919e93a39cac14a1cf8c333bea695` |
| `programmer+cust+3SJ11+ymtcx2.fw` | 626 688 | `1946eb385805a482d4cc88e1380a952b20a2e0bd9dd7e0825a82add5f8f93894` |
| `rdisk+cust+3SJ11+512b+hcrc+semi+l0ps+iecc+semiswitch+logerr+rel+mstripe+raid+a1perf_raid+ymtcx2-cmfg.fw` | 888 832 | `8994bf34259911cf780548a896b91bc66d9a2fd3c6740fd4693b085e5d910567` |

> O site de origem **não publica hashes oficiais**. Estes são os da **cópia que testamos**. Servem para detectar download corrompido e extração falha (o SHA-256 `e3b0c442…b855` é o de um arquivo **vazio**), não para provar autenticidade.

## 9. Como funciona, em resumo

```
ROM mode  ──ToRecovery──▶  loader (20 KB)  ──▶  programmer (~610 KB)  ──▶  rdisk (~870 KB)
(MN-5236)                                        └ inicializa DDR, enxerga a NAND    └ firmware normal; ativa após corte de energia
```

Lições que custaram tentativas (detalhes em [`docs/09`](docs/09-como-funciona.md)):

1. **Não mexa no registrador `CC`** do controlador depois do commit do loader: limpar `CC.EN` reinicia o controlador e derruba o loader. O loader leva ~**80 s** para responder; espere com **um** comando pendente.
2. **Não pause** entre loader e programmer: o controlador volta ao ROM.
3. **Um único processo** segura o dispositivo; se ele termina, o dispositivo pode cair em D3cold e ficar inacessível até um corte de energia.
4. **Não use `7z`** para extrair o pacote RAR (falha com "Unsupported Method" e deixa arquivos vazios): use `unrar`.

## 10. Problemas mais comuns

| Sintoma | Primeira coisa a fazer |
|---|---|
| `BAR0 ja le 0xFFFF...` / erro ao abrir `/dev/vfio/devices/vfioN` | **Corte total de energia** e refaça do `04` |
| `/dev/vfio/devices/` vazio | Rode o `04-preparar-vfio.sh` |
| Hash diferente / arquivo vazio | Use `unrar`; refaça o download; **não prossiga** |
| Programmer falhou (`status=None`) | Corte de energia; use o `06-run.sh` (confirmação única) |
| Continua `MN-5236` depois de tudo | O corte de energia não foi completo; repita com a fonte desligada |
| O SSD sumiu do `lspci` | **Pare.** Garantia, laboratório ou técnico |

Tabela completa: [`docs/08-solucao-de-problemas.md`](docs/08-solucao-de-problemas.md).

## 11. Compatibilidade

| Hardware | Situação |
|---|---|
| Netac NV7000 2 TB (YMTC) | ✅ Testado |
| Netac NV7000 1 TB (YMTC) | Relato de fórum com o mesmo pacote (via MPUtility) |
| NV7000 com NAND Micron B47R / SK hynix | Pacotes diferentes existem; **não testados** |
| Netac NV7000-T / -Q (Maxio MAP1602) | ❌ **Outro controlador** — este guia não serve |
| ADATA XPG, Fanxiang, Ant Esports… (IG5236) | Relatos de fórum com MPUtility; **não testado** por nós |
| Outros controladores | ❌ Não serve |

## 12. Publicar este repositório do zero

Se você recebeu este material como um `.zip`:

```bash
unzip recuperacao-ssd-ig5236.zip
cd recuperacao-ssd-ig5236
chmod +x scripts/linux/*.sh

git init -b main
git add .
git status                      # confira: nenhum .fw, .rar, .exe ou log deve aparecer
git commit -m "Guia de recuperação de SSD InnoGrit IG5236 (ROM mode MN-5236)"
```

Criar o repositório remoto e enviar:

```bash
# Opção A: GitHub CLI (precisa de `gh auth login` antes)
gh repo create recuperacao-ssd-ig5236 --public --source=. --remote=origin --push

# Opção B: crie um repositório vazio no site do GitHub e depois
git remote add origin git@github.com:SEU-USUARIO/recuperacao-ssd-ig5236.git
git push -u origin main
```

Depois, troque `<URL-DESTE-REPOSITORIO>` nos arquivos `README.md` e `docs/03`/`docs/05` pela URL real:

```bash
grep -rn "URL-DESTE-REPOSITORIO" .
```

## 13. Créditos e fontes

- **`Egorich-print/netac-nv7000-recovery`** (MIT) — o trabalho de engenharia reversa e o driver NVMe em espaço de usuário (`netac_pipeline.py`) em que o nosso `tools/guided_flash.py` se apoia. Sem ele, nada disto existiria.
- **usbdev.ru** — pacotes MPUtility, a página de arquivos e o fórum, cujos usuários documentaram o procedimento no Windows e as recuperações de NV7000.
- **量产部落 (club.liangchanba.com)** — fonte chinesa das ferramentas de produção do IG5236.
- **F3 (Fight Flash Fraud)**, de Michel Machado e colaboradores — teste de integridade.
- Análises de hardware (Club386, Guru3D, TechPowerUp) usadas para entender as variações de NAND do NV7000; o Rossmann Group, citado com ressalvas (site comercial), para a arquitetura do controlador.

As informações de terceiros estão marcadas como tal. O que **observamos** diretamente está em [`docs/09`](docs/09-como-funciona.md) e [`docs/exemplos/`](docs/exemplos/).

## 14. Licença

Os arquivos **deste repositório** estão sob a licença **MIT** ([`LICENSE`](LICENSE)). O código em `vendor/` (baixado por você) pertence ao autor original e tem a licença dele. Os arquivos de **firmware** pertencem a seus titulares e **não** são distribuídos aqui.
