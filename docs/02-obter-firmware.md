# 02 — Obter e verificar o firmware

Este repositório **não distribui firmware**. Os arquivos `.fw` pertencem aos titulares e vêm de pacotes de ferramentas de produção (MPUtility) publicados em sites de terceiros. Você mesmo precisa baixar o pacote certo.

> **Segurança.** O pacote contém um `MPUtility.exe` (Windows). **Não execute** esse `.exe` fora do caminho Windows deste guia, e mesmo lá apenas depois de verificá-lo (VirusTotal). No método Linux você só usa três arquivos `.fw`.

## Onde encontrar

| Fonte | Observações |
|---|---|
| `https://www.usbdev.ru/files/innogrit/ig5236mputility/` | Fonte principal que usamos. Site em russo. Tem um pacote por NAND/versão |
| 量产部落 (`club.liangchanba.com`), seção "原厂工具" → InnoGrit → IG5236 | Fonte chinesa. Exige cadastro; alguns arquivos custam "moedas" do site. **Não confirmamos** se o pacote Netac `3.S.J.11` está lá |

O site usbdev.ru **pode apresentar erro** no download (`HTTP 500`, "Temporary problems with downloading files"). Quando testamos, o problema era do servidor e atingia todos os arquivos da página. Se acontecer: tente outro horário, avise o administrador por comentário na página, e **não** pegue o arquivo em cópias de terceiros sem verificar (veja abaixo).

Tentativa por linha de comando (o ID `14082` é o do `netac_3.S.J.11_external.rar` na página; confira na página, que pode mudar):

```bash
UA="Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
curl -sL -A "$UA" -c cj.txt -o /dev/null "https://www.usbdev.ru/files/innogrit/ig5236mputility/"
curl -L -A "$UA" -b cj.txt -c cj.txt \
  -e "https://www.usbdev.ru/files/innogrit/ig5236mputility/" \
  -D headers.txt -o netac.rar "https://www.usbdev.ru/?wpfb_dl=14082"
cat headers.txt; ls -l netac.rar; file netac.rar
```

Se o `file` disser **HTML document** (e o arquivo tiver ~2,5 KB), é a página de erro do servidor, não o firmware. Apague e tente depois.

## Qual pacote baixar

Veja a tabela da NAND em [`01-diagnostico.md`](01-diagnostico.md#5-descobrir-a-nand-o-passo-que-decide-o-pacote-de-firmware). O fluxo testado neste repositório é o pacote **`netac_3.S.J.11_external.rar`** (NAND YMTC).

## Como verificar o download

O site **não publica hash oficial**. Use três sinais:

1. **Tamanho exato**: `51530689` bytes.
   ```bash
   stat -c %s netac_3.S.J.11_external.rar
   ```
2. **Integridade do RAR**:
   ```bash
   unrar t netac_3.S.J.11_external.rar     # deve terminar com "All OK"
   ```
3. **Hash de referência** (da cópia que testamos; serve para comparar com a sua, **não** é uma garantia de autenticidade):
   ```
   fc0f74f46aba91874b574f9c42d8abb7bf9c19d039e68a74a015df85d1d71b3c  netac_3.S.J.11_external.rar
   ```
   ```bash
   sha256sum netac_3.S.J.11_external.rar
   ```
   Cole o hash em `virustotal.com` (aba "Search") para ver se o arquivo é conhecido, **sem** enviar o arquivo.

## Extrair só o que precisamos

Use o script (extrai apenas os três `.fw`, não toca no `.exe`):

```bash
./scripts/linux/02-extrair-firmware-3SJ11.sh ~/Downloads/netac_3.S.J.11_external.rar
```

Ele faz `unrar t`, extrai para `firmware/m2_0536/`, protege os arquivos contra escrita e roda `tools/verificar_firmware.py`.

> **Não use `7z` para extrair.** O 7-Zip 23.01 que testamos lista o conteúdo, mas **falha com "Unsupported Method"** e deixa arquivos de **0 bytes**. Se você copiar esses arquivos vazios, o hash será `e3b0c442…b855` (SHA-256 de um arquivo vazio). Use `unrar`.

### Resultado esperado

| Arquivo (em `firmware/m2_0536/`) | Tamanho | SHA-256 |
|---|---|---|
| `loader.fw` | 20 480 | `94fde6004d6ba0b0b2d149731735b5385ee919e93a39cac14a1cf8c333bea695` |
| `programmer+cust+3SJ11+ymtcx2.fw` | 626 688 | `1946eb385805a482d4cc88e1380a952b20a2e0bd9dd7e0825a82add5f8f93894` |
| `rdisk+cust+3SJ11+512b+hcrc+semi+l0ps+iecc+semiswitch+logerr+rel+mstripe+raid+a1perf_raid+ymtcx2-cmfg.fw` | 888 832 | `8994bf34259911cf780548a896b91bc66d9a2fd3c6740fd4693b085e5d910567` |

Para conferir a qualquer momento:

```bash
python3 tools/verificar_firmware.py
```

Deve terminar com `TUDO CONFERE`. **Se algum hash divergir, não prossiga.**

O pacote também traz variantes `rdt` e `Config_New.ini`; **não são usadas** neste método.

## Usar outro pacote (não testado)

O script lê os nomes e hashes de um descritor JSON (`firmware/pacote-3SJ11.json`). Para outro pacote, copie o arquivo, ajuste `nand`, os nomes, tamanhos e hashes, e aponte para ele:

```bash
NETAC_PACOTE=$PWD/firmware/pacote-MEU.json ./scripts/linux/05-check.sh
```

**Não testamos** nenhum outro pacote. O fluxo (loader → programmer → rdisk) é o mesmo no pacote que usamos; se o seu tiver estrutura diferente (por exemplo, sem a página `CMFG` no rdisk), o comportamento pode mudar. Se tentar, relate o resultado ([`10-relatar-resultado.md`](10-relatar-resultado.md)).

## Próximo passo

→ [`03-linux-passo-a-passo.md`](03-linux-passo-a-passo.md) (ou, só com Windows, [`04-windows-mputility.md`](04-windows-mputility.md) / [`05-windows-via-linux-live.md`](05-windows-via-linux-live.md)).
