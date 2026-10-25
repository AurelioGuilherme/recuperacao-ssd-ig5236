# 01 — Diagnóstico: é mesmo o seu caso?

Nesta etapa você **só lê informações**. Nada é gravado.

## 1. Sintomas típicos

- Antes: travamentos ao gravar muito dado, erro de boot (`0xc000000e` no Windows), às vezes resolvido forçando o desligamento.
- Depois: o SSD "some" e reaparece como um disco de **~2 GB**, não inicializado, de nome **MN-5236**.

## 2. Confirmar no Linux

```bash
lspci -nn | grep -i -E "non-volatile|nvme|innogrit"
sudo nvme list
```

Assinatura do ROM mode (o que vimos):

| Onde | Valor típico em ROM mode |
|---|---|
| `lspci -nn` | `INNOGRIT Corporation NVMe DC SSD IG5636 [1dbe:5636]` |
| `nvme list` — SN | `SSD-5236` |
| `nvme list` — Model | `MN-5236` |
| `nvme list` — FW Rev | `2.0.0.3` |
| `nvme list` — tamanho | `2.15 GB`, formato `4 KiB` |
| `nvme id-ctrl` | quase tudo zerado (`ver`, `ieee`, `cntlid`, `fguid`…) |
| `nvme smart-log` | tudo zero e temperatura `-273 °C` |
| `dmesg` | `nvme nvme0: request 0x.. genctr mismatch` / `invalid id .. completed on queue 0` |

Se o `lspci` mostrar **`1dbe:5236`** e o `nvme list` mostrar a capacidade real, o seu SSD **não** está em ROM mode: este guia não se aplica.

Para guardar tudo num arquivo (é útil para pedir ajuda ou acionar a garantia):

```bash
./scripts/linux/03-diagnostico.sh
```

## 3. Confirmar no Windows

- **Gerenciamento de Disco** (`diskmgmt.msc`): um disco de ~2 GB "Não inicializado" e/ou com nome `MN-5236`.
- No **Gerenciador de Dispositivos → Unidades de disco**, o nome também será `MN-5236`.
- Script deste repositório (somente leitura; PowerShell como Administrador):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\windows\diagnostico.ps1
```
  Procure `DEV_5636` na saída dos dispositivos PCI `VEN_1DBE`.

## 4. Casos em que este guia NÃO se aplica

| O que você vê | O que é | O que fazer |
|---|---|---|
| SSD não aparece em lugar nenhum (BIOS, `lspci`) | Falha de hardware, slot, ou controlador morto | Teste outro slot/PC. Depois: garantia ou laboratório |
| `lspci` mostra `1dbe:5236` e capacidade real | Firmware completo, problema é de sistema de arquivos | Use as ferramentas normais (`ntfsfix`, `chkdsk`) |
| Controlador de outra marca (Phison, Maxio, SMI…) | Outro procedimento | Este guia **não** serve |
| Aparece com 2 GB mas o `lspci` mostra outro vendor ID | Outro controlador em modo de falha | Pesquise o seu controlador |

## 5. Descobrir a NAND (o passo que decide o pacote de firmware)

O pacote de firmware tem de corresponder à **NAND** do seu SSD. O controlador, em ROM mode, **não informa a NAND**: no nosso teste, o `mpinfo` só trouxe a identificação depois de o programmer estar rodando — e a essa altura o programmer (que é específico de NAND) já tinha sido gravado. Por isso a leitura física, **antes** de gravar, é a forma mais segura.

### Como ler

1. Desligue o PC, tire da tomada, retire o SSD do slot.
2. Remova o dissipador/etiqueta metálica (isso pode anular a garantia). Há uma almofada térmica; levante com cuidado.
3. A placa do NV7000 que analisamos tinha **três chips grandes**:
   - o **controlador** (quadrado pequeno e azulado sobre um bloco preto): `INNOGRIT IG5236CAA`;
   - **uma DRAM** (retângulo com logotipo), no nosso caso `SK hynix H5AN8G6NCJ` — **isso é memória DDR4, não NAND**. Ver "Hynix" aqui **não** significa NAND Hynix;
   - **dois chips de NAND** (retângulos pretos grandes, sem logotipo visível sob a almofada).
4. Limpe o resíduo da pasta térmica com álcool isopropílico e um pano sem fiapos (sem esfregar).
5. Fotografe cada chip de NAND de perto, com **luz rasante** (lanterna do celular quase paralela à superfície): o texto é gravado a laser e some com luz de frente.

### Como interpretar

| Marcação | Fabricante | Observação |
|---|---|---|
| Começa com `NTEF…` (nós lemos algo como `NTEF04TY3EL1G9`) | **YMTC** | Associação publicada por uma análise de um Netac; o prefixo é o que importa |
| Logotipo/códigos Micron | Micron (B47R) | Pacotes `3.A.J.CR`, `3.2.F.2F`, `3.2.F.74` |
| `H25…` (código de NAND) | SK hynix | Pacote `3.W.J.E4`. **Não confunda com `H5A…`/`H5AN…`, que é DRAM** |

### Pacotes listados no site de origem (usbdev.ru)

O site lista um pacote por NAND/versão. **Só o `3.S.J.11` foi testado por nós.**

| Tag do pacote | NAND |
|---|---|
| `YMTC_TAS-3.S.J.11` (`netac_3.S.J.11_external.rar`) | YMTC — **testado** |
| `YMTC_TAS-3.2.F.3Y`, `3.2.F.66`, `3.2.F.83`, `3.F.F.R2`, `3.W.J.1`, `3.W.J.CL` | YMTC (outras versões/produtos) |
| `B47R-3.A.J.CR`, `3.2.F.2F`, `3.2.F.74` | Micron B47R |
| `HynixV7-3.W.J.E4` | SK hynix V7 |

Dois sinais que usamos para escolher o `3.S.J.11` no nosso NV7000: marcação `NTEF` na NAND, e o PN/QC do adesivo (`NT01NV7000-2T0-E4X`, QC 11/2022) iguais aos de um relato de fórum que recuperou um NV7000 1 TB com esse pacote.

### Confirmação depois (para ter certeza)

Quando o programmer está rodando, o script mostra o `mpinfo` decodificado. No nosso disco apareceram 16 entradas `9b c5 29 49 20 00`, e `0x9B` é o código de fabricante da YMTC. **O offset usado para decodificar vem de outro projeto e não foi verificado por nós**, mas o padrão regular e o código batem com a marcação `NTEF` do chip. Se aparecer um fabricante diferente do esperado, **não digite a frase da etapa destrutiva**.

## Próximo passo

→ [`02-obter-firmware.md`](02-obter-firmware.md)
