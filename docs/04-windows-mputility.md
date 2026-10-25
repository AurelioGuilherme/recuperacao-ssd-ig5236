# 04 — Windows: solução da comunidade (MPUtility)

> **Estado de teste: NÃO testado por nós.** Esta página resume o procedimento relatado por vários usuários em um fórum e nos comentários do site usbdev.ru (Netac NV7000, ADATA XPG, Ant Esports e outros discos com IG5236). Os relatos mostram sucesso em discos com NAND YMTC e Hynix, mas **não temos como garantir** o resultado, e as fontes são anônimas. Leia [`00-antes-de-comecar.md`](00-antes-de-comecar.md) antes.
>
> Se você quer o caminho que **nós** testamos e só tem Windows, veja [`05-windows-via-linux-live.md`](05-windows-via-linux-live.md).

## O que é o MPUtility

Uma ferramenta de produção ("MP tool") da InnoGrit/fabricantes, com interface gráfica, que carrega o loader, o programmer e o firmware de runtime no controlador. Os pacotes são um por NAND/versão (veja a tabela em [`01-diagnostico.md`](01-diagnostico.md#pacotes-listados-no-site-de-origem-usbdevru)). O pacote `netac_3.S.J.11_external.rar` traz o `MPutility.exe`, o `Config_New.ini` e a pasta `m2_0536` com os `.fw`.

## Cuidados específicos do Windows

- O `MPUtility.exe` vem de um site de terceiros, sem assinatura confiável. **Passe o hash no VirusTotal antes** (aba Search). Se possível, use um PC que não seja o seu principal.
- Para extrair o `.rar`, use **WinRAR** ou um 7-Zip recente. O 7-Zip 23.01 que testamos no Linux listou o conteúdo e falhou com "Unsupported Method". Se acontecer, troque de extrator.
- **Desconecte (ou desative) outros SSDs NVMe** durante o procedimento, para não selecionar o disco errado.
- Instale o SSD **direto no slot M.2** da placa-mãe (ou num adaptador PCIe). Os relatos de sucesso foram assim. **Adaptadores USB-NVMe** são problemáticos (no projeto upstream, uma ponte JMS583 travou com o disco).
- Feche CrystalDiskInfo, Gerenciamento de Disco, Explorador de Arquivos e qualquer utilitário de SSD.

## Passo a passo (segundo os relatos)

### 1. Identifique a NAND

- Pelas marcações físicas, como em [`01-diagnostico.md`](01-diagnostico.md#5-descobrir-a-nand-o-passo-que-decide-o-pacote-de-firmware).
- Um relato sugere também o utilitário **Innogrit NVMe Flash ID** (no mesmo site). Dois usuários disseram que ele **não** mostrou a NAND em ROM mode; um deles confirmou a NAND depois, pelo próprio MPUtility.

### 2. Baixe o pacote correspondente

Veja [`02-obter-firmware.md`](02-obter-firmware.md). Um comentarista sugere tentar, se a NAND for conhecida, os pacotes dessa NAND **em ordem decrescente de versão** até um funcionar.

### 3. Entre no modo engenheiro

1. Execute `MPutility.exe` **como administrador**.
2. Clique no botão **Operator** (canto superior direito) e informe a senha **`0000`** (indicada pelo site e pelos usuários).

### 4. Confirme que o SSD está em recovery

No MPUtility ou no Gerenciamento de Disco, o SSD deve aparecer como **`MN-5236`, ~2 GB**.

- Se ele **já** aparece assim, **não precisa de jumper**.
- O botão **"To Recovery Mode"** (canto inferior direito) é descrito como o jeito de colocar o controlador em recovery e fazer o programa detectar a memória.

### 5. Carregue a configuração

Use o `Config_New.ini` (ou `Config_New_K3_2LUN.ini`, no pacote da Ant Esports) **que vem no pacote**.

### 6. Grave

1. Clique em **Scan**.
2. Selecione o SSD (confira o modelo e o tamanho: **~2 GB**).
3. Clique em **Start** (Enter).
4. **Não interrompa.** Aguarde o **PASS** e a NAND identificada (ex.: `YMTC-X2-9060` num relato).

### 7. Corte total de energia

Desligue o PC (**não reinicie**) e **remova a energia AC por cerca de 30 segundos**. Ligue de novo.

### 8. Inicialize o disco

No Gerenciamento de Disco, o SSD deve aparecer com a capacidade real e "Não inicializado/Não alocado". Inicialize como **GPT**, crie o volume e formate.

### 9. Valide

CrystalDiskInfo (capacidade, "Critical Warning" 0, erros 0), **H2testw** em todo o disco, várias reinicializações a frio. Veja também [`06-pos-recuperacao.md`](06-pos-recuperacao.md).

## Se o processo travar ou o SSD desaparecer

Relatos:

- Um usuário gravou o pacote Hynix num disco que **não** era Hynix: o MPUtility travou em ~30%, mostrou "disco perdido", e o SSD **não aparecia mais**.
- A solução relatada foi usar o ponto de **ROM jumper** da placa e tentar outro pacote.
- Os usuários dizem para **tirar o jumper assim que o SSD aparecer como `MN-5236`** (não gravar com o jumper ligado).

### Se o disco sumiu do barramento

Os relatos descrevem **curto-circuitar dois pontos de teste da placa** (um deles identificado como GPIO11 e o outro como 1V8) com um clipe, com o PC ligado, até o SSD reaparecer como `MN-5236`.

**Este repositório não ensina esse procedimento**, por três razões:

1. **Não confirmamos qual ponto é qual na sua placa.** Fotografamos um NV7000 2 TB e vimos uma fileira de furos de teste com marcações legíveis como `1V8`, `GND`, `SWCLK`, `SWDIO`, `GPIO10`, `HR1`, `UTX` e `URX`. O relato fala em `GPIO11`. Não encontramos documentação oficial.
2. **Um curto na linha de 1,8 V pode danificar o SSD de vez.**
3. Funciona **só** com a NAND correta; se o pacote estava errado, o curto só te devolve o ROM mode.

Se chegar a esse ponto, procure o relato original no fórum do usbdev.ru, ou um técnico de eletrônica, ou um laboratório.

## Referência rápida: escolhas que os relatos recomendam

| Situação | Ação relatada |
|---|---|
| Disco já aparece como MN-5236 | Não use jumper |
| Não sabe a NAND | Descubra pelas marcações; ou use o MPUtility para identificar |
| Travou e sumiu | Jumper ROM (por conta e risco) e outro pacote |
| Terminou com PASS | Desligar de verdade, cortar a energia, inicializar |
| Ainda 2 GB depois | **Não** grave pacotes aleatórios: reconfira a NAND |
