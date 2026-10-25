# 00 — Antes de começar

Leia esta página inteira antes de rodar qualquer comando. Ela diz o que este guia resolve, o que **não** resolve e o que você pode perder.

## O que este guia faz

Tira da condição de "disco morto" um SSD NVMe com controlador **InnoGrit IG5236** que ficou preso no *ROM mode*:

- aparece com **cerca de 2 GB** (2,15 GB) em vez da capacidade real;
- tem o nome genérico **`MN-5236`** (serial `SSD-5236`, firmware `2.0.0.3`);
- no Linux, o `lspci` mostra `1dbe:5636` ("NVMe DC SSD IG5636");
- não aparece partição nenhuma e o Windows pede para inicializar um disco de 2 GB.

O procedimento regrava o firmware do controlador (loader → programmer → rdisk). Foi testado em **um** disco, o **Netac NV7000 2 TB** (PN `NT01NV7000-2T0-E4X`, NAND YMTC). Veja o resultado completo em [`exemplos/`](exemplos/).

## O que este guia NÃO faz

- **Não recupera dados.** O procedimento inclui etapas de reinicialização de fábrica. Trate tudo o que estava no SSD como perdido. Um laboratório que estudou esse controlador afirma que ele usa criptografia sempre ativa com chave presa ao controlador (informação de um site comercial de recuperação, não verificada por nós). Se os dados são insubstituíveis, pare aqui e consulte um laboratório *antes* de qualquer coisa. Pergunte, por escrito, se eles atendem o InnoGrit IG5236 em ROM mode.
- **Não conserta hardware defeituoso.** Se o SSD nem aparece no `lspci`/Gerenciador de Dispositivos, o problema é outro.
- **Não garante que o problema não volta.** Não sabemos a causa raiz da falha original (no nosso caso, o disco travou durante uma instalação de 130 GB e já vinha travando antes). Há um comentário em fórum, sem fonte, de que o IG5236 tem uma falha de firmware sob carga mista. Não conseguimos verificar. Mantenha backup.
- **Não é um procedimento oficial.** Nem da Netac, nem da InnoGrit, nem de ninguém ligado a elas.

## Estado de teste (honestidade primeiro)

| Item | Estado |
|---|---|
| Linux, método deste repositório | **Testado em 1 disco** (Netac NV7000 2 TB, NAND YMTC, pacote `3.S.J.11`) |
| Windows com MPUtility | **Não testado por nós.** Baseado em relatos de vários usuários em fórum |
| Windows via pendrive Linux Live | Usa o mesmo método do Linux; **não testamos o pendrive Live** em si |
| Outros pacotes de firmware (Micron B47R, SK hynix) | **Não testados** |
| Outras marcas com IG5236 (ADATA, Fanxiang, Ant Esports…) | **Não testado** |
| Script de diagnóstico para Windows (`.ps1`) | **Não executado** por nós (somente revisado) |

## Riscos

1. **Pacote de firmware errado.** Cada pacote é para um tipo de NAND. Um relato de fórum: ao gravar o pacote errado (Hynix num disco YMTC), o processo travou em ~30% e o SSD **sumiu do barramento**. Só voltou depois de curto-circuitar um ponto de ROM na placa. Este guia **não** ensina o curto-circuito com segurança (veja [`04-windows-mputility.md`](04-windows-mputility.md#se-o-disco-sumiu-do-barramento)).
2. **Interromper no meio.** Fechar o terminal, Ctrl+C, suspensão do PC ou queda de energia durante a gravação podem deixar o disco num estado que só um corte de energia desfaz — ou pior.
3. **Código e firmware de terceiros.** Os arquivos `.fw` e o `MPUtility.exe` vêm de sites de terceiros, sem assinatura. O `.exe` **não é necessário** no método Linux e **nunca** deve ser executado em sua máquina principal sem verificação.
4. **Escolher o disco errado.** Os scripts têm travas (recusam discos montados), mas **você** é a última linha de defesa. Confira o dispositivo toda vez.
5. **Garantia.** O adesivo do SSD diz "WARRANTY VOID IF REMOVED". Remover o dissipador para ler a NAND pode anular a garantia. **Se o SSD ainda está na garantia, tente a garantia primeiro.**

## Tempo e dificuldade

- Primeira vez: **2 a 4 horas** (a maior parte é reunir arquivos, ler e testar). A gravação em si leva uns 5 a 10 minutos.
- Exige: usar terminal Linux, abrir o PC, ler saídas de comando. Não é para iniciantes absolutos, mas cada passo está explicado.

## O que você precisa

**Hardware**
- O SSD com problema, instalado num slot M.2 do PC (**ou** num adaptador PCIe/M.2 — um adaptador USB-NVMe **não serve** para o método Linux deste repositório, que acessa o dispositivo diretamente pelo barramento PCIe).
- **Outro disco** com Linux instalado (SATA, outro NVMe, ou pendrive Live). O SSD a recuperar **não pode** ser o disco do sistema.
- Chave de fenda e, se possível, uma pulseira antiestática, para abrir o dissipador e ler as marcações da NAND.
- Um PC que você possa deixar ligado, na tomada, por ~15 minutos sem mexer.

**Software (Linux)**
- Kernel **6.6 ou mais novo** (precisa de VFIO "cdev" e iommufd). Testado: Ubuntu 24.04, kernel 6.8.
- **IOMMU ligado na BIOS** (AMD-Vi / SVM / "IOMMU" em AMD; VT-d em Intel).
- Python 3, `git`, `pciutils`, `nvme-cli`, `smartmontools`, `f3`, `parted`, `unrar`.
- Acesso a `sudo`.

**Arquivos**
- O pacote de firmware correto para a NAND do seu SSD (veja [`02-obter-firmware.md`](02-obter-firmware.md)).

## Aviso legal

Este material é fornecido "como está", sem garantia de qualquer tipo, para fins educacionais e de reparo do **seu próprio** equipamento. Você assume todo o risco. Os autores não têm vínculo com Netac, InnoGrit ou os sites citados. Os arquivos de firmware pertencem a seus titulares e **não** são distribuídos aqui.

## Próximo passo

→ [`01-diagnostico.md`](01-diagnostico.md): confirmar que o seu caso é mesmo ROM mode do IG5236 e descobrir qual NAND você tem.
