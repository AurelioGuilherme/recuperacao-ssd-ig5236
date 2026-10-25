# 09 — Como funciona (e o que aprendemos errando)

Esta página é técnica. Separamos o que **observamos** do que é **hipótese** ou vem de **outra fonte**.

## Visão geral

Um SSD NVMe tem um **controlador** que roda um firmware guardado na própria NAND. Se esse firmware não carrega, o controlador cai num programa mínimo de fábrica, o **ROM mode**, e responde com uma identidade genérica (`MN-5236`, 2 GB virtuais). Recuperar o disco é entregar a ele, pelo barramento PCIe, três imagens em sequência:

```
ROM mode  ──ToRecovery──▶  loader  ──▶  programmer  ──▶  rdisk (firmware de runtime)
(MN-5236)                 (20 KB)      (~610 KB)         (~870 KB)  ── corte de energia ──▶ disco normal
```

- **loader**: prepara o ROM para aceitar imagens maiores.
- **programmer**: roda na RAM do controlador, inicializa a DDR, enxerga a NAND (aqui o `mpinfo` passa a informar a NAND) e executa as operações de fábrica.
- **rdisk**: o firmware de uso normal. Só passa a valer depois de um **corte total de energia**.

Esses papéis vêm da documentação do projeto upstream e de relatos de fórum; confirmamos a sequência e as identidades que aparecem em cada etapa, não o funcionamento interno.

## Como o Linux fala com o controlador

O projeto upstream (`Egorich-print/netac-nv7000-recovery`, MIT) implementa em Python um **driver NVMe em espaço de usuário**: abre o dispositivo PCIe por **VFIO (cdev) + iommufd**, mapeia o BAR0, cria a fila de comandos administrativos e envia comandos. Isso evita o driver `nvme` do kernel, que tentaria reinicializar o controlador e não conhece os comandos específicos da InnoGrit.

Pontos do upstream que seguimos: fila de admin com **2 entradas** (`NETAC_QSIZE=2`); `vfio-pci disable_idle_d3=Y` e `d3cold_allowed=0`; **todas as etapas num único processo**.

## Comandos usados

Opcode | Uso | Fonte do significado
---|---|---
`0xF7` (cdw12=1, "GRIT"/"INNO" em cdw14/15) | ToRecovery: põe o ROM em recovery | upstream
`0x11` + `0x10` | Download e Commit de firmware (padrão NVMe). `0x10` com `cdw10=0x19`: pela especificação, slot 1 + ação 3 (substituir e **ativar imediatamente**) | NVMe + upstream
`0xE4` (cdw12=3) | Treino da DDR ("DDR eye") | upstream
`0xF2` | `mpinfo`: página com informações do controlador e da NAND | upstream
`0xE6` / `0xE5` | Ler / gravar a página de configuração (CONF) | upstream
`0xE4` (cdw12=1 / cdw12=5), `0xD0` | `BrandNew`, `RemoveCheck`, `SmartClean` (reinicialização de fábrica) | upstream — **nomes; o efeito exato não foi verificado por nós**, só vimos os status `0`

Detalhe de NSID: loader e programmer são baixados com NSID `0xFFFFFFFF`; o rdisk, com NSID `0` (o upstream relata que, em modo programmer, `0xFFFFFFFF` dá "Invalid Field").

## Linha do tempo observada (execução bem-sucedida)

| Etapa | O que vimos |
|---|---|
| Início | `CAP=0x…20640100ff`, `MN-5236`, `SSD-5236`, `2.0.0.3` |
| `ToRecovery` | status 0 |
| Loader | 5 chunks em 0,04 s, commit status 0 |
| Espera | `CC=0x00460001` constante; **o Identify só respondeu após 80,2 s** (e voltou com a identidade de ROM) |
| Programmer | 153 chunks em 1,16 s, commit status 0 |
| Depois do programmer | Identify respondeu em 12,6 s: `SSD-DRAM-120216-V` / `INNOGRIT` / `3.S.J.11` |
| DDR + `mpinfo` | `DDR eye: 0`; 284 bytes não-zero; 16 entradas `9bc529492000` (fabricante `0x9B`) |
| Etapa destrutiva | `BrandNew` 0, `RemoveCheck` 0, rdisk 888 832 bytes, CONF (`crc32=0xbded00a7`) 0, `commit 0x19` 0, `SmartClean` 0, `BrandNew` 0 |
| Antes do corte | identidade ainda `SSD-DRAM-120216-V` (esperado) |
| Depois do corte | `1dbe:5236`, `SSD-DRAM-120216-F`, `INNOGRIT`, 2,00 TB, 512 B, FW `3.S.J.11`; `nvme0n1` 1,8 TiB |
| F3 | 100 GB OK; depois 1,70 TB OK (zero em corrompido/alterado/sobrescrito) |

## Lições aprendidas (cada uma custou uma ou mais tentativas)

1. **Não toque no registrador `CC` depois de um commit.** Limpar `CC.EN` (o que o `enable()` faz) é um reset de controlador pela especificação NVMe. Depois do loader, isso derrubou o controlador de volta ao ROM e fez parecer que "o loader não funciona". O loader precisa de ~80 s para ficar pronto; **espere** com **um** comando pendente.
2. **Não pause entre loader e programmer.** Quando o script esperava uma confirmação manual entre os dois, o controlador voltou ao ROM e o download do programmer falhou no meio (`status=None`, `CSTS=0`). Por isso as duas etapas são confirmadas juntas.
3. **Um único processo.** Quando o processo que segura o dispositivo termina, o `vfio-pci` fecha o dispositivo e ele pode cair em D3cold e ficar inacessível (BAR0 lê `0xFFFFFFFF`). Só um corte de energia desfaz. Por isso o script entra em `hold` em vez de sair.
4. **Não deixe o PC parado depois de preparar o VFIO.** Vimos o dispositivo morrer só por ficar ocioso por horas.
5. **Não use `7z` para o pacote RAR.** `Unsupported Method` e arquivos vazios.
6. **Esperas passivas ≠ polling agressivo.** Reabilitar o controlador a cada poucos segundos (como faz o `megaflash4` do upstream) pode funcionar no hardware do autor (onde o loader provavelmente responde bem mais rápido) e **não** no nosso.
7. **Keepalive na etapa destrutiva.** Enquanto esperamos a confirmação, mandamos um `mpinfo` (leitura) a cada 3 s. É um palpite que se mostrou inofensivo; não sabemos se é necessário.

## O que não sabemos

- Por que o disco original travou, e se pode voltar a travar.
- Se o offset `0x24E` do `mpinfo` está certo para todas as variantes (veio de outro projeto; o resultado coerente no nosso disco é um indício, não uma prova).
- Se o `percentage_used` de 4% é desgaste real.
- Como outros pacotes (Micron, Hynix) se comportam neste fluxo.
- Se o método funciona em placas/CPUs/kernels muito diferentes do nosso.

## Tentativas que falharam (para você reconhecer)

| Tentativa | Resultado | Lição |
|---|---|---|
| `nvme reset`, `subsystem-reset`, `setpci`, `remove/rescan`, cortes de CMOS | Nada muda | O problema está dentro do SSD |
| `ssd-flash-id` (Linux) / Flash ID | `mpinfo` vazio em ROM mode | A NAND só aparece com o programmer rodando |
| Loader + Identify imediato (reabilitando o controlador) | Timeout; controlador volta ao ROM | Lição 1 |
| Loader, pausa manual, programmer | `status=None` no chunk #1 | Lição 2 |
| Encerrar o processo no meio | BAR0 `0xFFFF…`, D3cold | Lição 3 |
