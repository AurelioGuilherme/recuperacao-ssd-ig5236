# 05 — Windows: usando o método Linux a partir de um pendrive Live

Se você só tem Windows, **não precisa instalar Linux no PC**. Dá para rodar o método testado deste repositório a partir de um pendrive "Live" (o Linux roda do pendrive, sem tocar nos seus discos).

> Estado de teste: o **método** (Linux) foi testado num sistema instalado. Rodá-lo a partir de um pendrive Live **não foi testado por nós**. A lógica é a mesma, mas detalhes (Secure Boot, memória, rede) podem variar.

## O que você precisa

- Um pendrive de 8 GB ou mais (será apagado).
- O SSD com problema instalado no **slot M.2 do PC** (ou num adaptador PCIe).
- Internet no PC durante a sessão Live (para instalar pacotes e baixar o repositório).
- IOMMU ligado na BIOS (AMD: `IOMMU`/`AMD-Vi` e `SVM`; Intel: `VT-d`).
- Outro pendrive ou pasta para guardar logs (a sessão Live **perde tudo** ao desligar).

## 1. Criar o pendrive

1. Baixe o **Ubuntu 24.04 LTS Desktop** (ISO) em `ubuntu.com`.
2. No Windows, use **Rufus** ou **balenaEtcher** para gravar a ISO no pendrive.

## 2. Dar boot no pendrive

1. Reinicie e abra o menu de boot da placa (geralmente F12, F11, Esc ou F8).
2. Escolha o pendrive (entrada UEFI).
3. No menu do Ubuntu, escolha **"Try Ubuntu"** (**não** instale).
4. Se o boot falhar com Secure Boot, desative-o na BIOS. (Não verificamos se o `vfio-pci` funciona com Secure Boot ligado.)

## 3. Preparar a sessão Live

No Live, **não abra os discos internos no gerenciador de arquivos** (isso os monta). Abra um terminal:

1. **Desative o bloqueio de tela e a suspensão**: Configurações → Energia → "Suspensão automática" desativada; Privacidade → Bloqueio de tela desativado.
2. Habilite o repositório `multiverse` (para o `unrar`) e atualize:
   ```bash
   sudo add-apt-repository -y multiverse
   sudo apt-get update
   sudo apt-get install -y git
   ```
3. Baixe este repositório e entre nele:
   ```bash
   git clone <URL-DESTE-REPOSITORIO> recuperacao-ssd-ig5236
   cd recuperacao-ssd-ig5236
   chmod +x scripts/linux/*.sh
   ```
4. Instale as dependências:
   ```bash
   ./scripts/linux/00-instalar-dependencias.sh
   ```

## 4. Seguir o guia Linux

A partir daqui, é o [`03-linux-passo-a-passo.md`](03-linux-passo-a-passo.md), **a partir do Passo 3** (baixar o upstream). Notas específicas do Live:

- **O firmware**: baixe dentro do próprio Live (navegador do Ubuntu) ou copie de outro pendrive. Depois: `./scripts/linux/02-extrair-firmware-3SJ11.sh caminho/do/arquivo.rar`.
- **O disco do sistema** é o próprio pendrive/RAM, então o SSD a recuperar não está montado. O `04-preparar-vfio.sh` recusa se achar partições montadas nele.
- **Logs**: copie `logs/*` para um pendrive de dados **antes** de desligar.
- **Depois da gravação**, o corte de energia vale igual: desligue o Live, corte a energia da fonte por 30 s, ligue. Pode dar boot direto no Windows (ou no pendrive Live, se for rodar o `07`).
- **Depois**, no Windows: o SSD aparece com a capacidade real e não inicializado. Inicialize como GPT e reinstale o Windows.

## Por que não portamos o script para Windows

Perguntaram se dava para portar "o que fizemos" para Windows. **Não construímos nem testamos** um port, de propósito. Os motivos são técnicos, e eles também aparecem como hipóteses: não os validamos no Windows.

1. **Quem controla o controlador é o driver `stornvme`.** No Linux, o que fez funcionar foi um único processo dono do dispositivo (via VFIO) que **não toca no registrador `CC`** depois do commit do loader. Mexer no `CC` reinicia o controlador e derruba o loader (veja [`09-como-funciona.md`](09-como-funciona.md)). No Windows, o driver pode reiniciar o controlador por timeout sozinho; um loader que leva ~80 s para responder seria um problema.
2. **Comandos administrativos "crus".** O método usa os comandos NVMe `Firmware Image Download` (`0x11`) e `Firmware Commit` (`0x10`) com parâmetros exatos, mais comandos específicos da InnoGrit. Pelo que sei, o Windows costuma expor esse tipo de acesso por `IOCTL_STORAGE_PROTOCOL_COMMAND`, mas **não validamos** se o `stornvme` aceita esses opcodes e esses parâmetros no ROM mode.
3. **Risco.** Um script de gravação de firmware que nunca foi executado num disco real pode enganar quem o usa.

Se você quiser tentar, o que existe para Windows com histórico de sucesso é o MPUtility: [`04-windows-mputility.md`](04-windows-mputility.md).
