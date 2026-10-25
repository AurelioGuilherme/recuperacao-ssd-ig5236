# 06 — Depois da recuperação

O SSD voltou a mostrar a capacidade real. **Isso ainda não prova que ele é confiável.** O SMART só diz que o controlador subiu. Faça estes testes antes de guardar dados importantes nele.

## 1. Conferir o estado

```bash
./scripts/linux/07-verificar-pos-power-cycle.sh
```

No nosso caso: `1dbe:5236`, modelo `INNOGRIT`, FW `3.S.J.11`, 2,00 TB, `critical_warning 0`, `media_errors 0`, `num_err_log_entries 0`. O `percentage_used` mostrou **4%** logo depois (e continuou 4% depois de 1,7 TB de escrita). **Não sabemos de onde vêm esses 4%**: podem ser desgaste real de um disco de 2022 ou um valor inicial do firmware.

## 2. Recoloque o dissipador

Se você abriu o SSD, recoloque o dissipador e as almofadas térmicas. Nosso teste completo foi feito **sem** eles (58 °C ao fim de uma escrita e leitura contínuas). Com o dissipador a temperatura deve ser menor, mas não medimos.

## 3. Teste de integridade com F3

O F3 escreve arquivos de 1 GB com conteúdo verificável e depois os lê de volta. Detecta capacidade falsa, NAND com defeito e firmware que gerencia mal os blocos. **Ele apaga o disco indicado.**

```bash
lsblk -o NAME,MODEL,SIZE,TYPE          # confirme QUAL é o disco
./scripts/linux/08-teste-f3.sh /dev/nvme0n1 rapido      # ~100 GB
./scripts/linux/08-teste-f3.sh /dev/nvme0n1 completo    # disco inteiro (horas)
```

O script recusa discos montados e o disco que contém `/`, e pede que você **digite o caminho do dispositivo** para confirmar. Esperado no fim:

```
Data OK: ...
Data LOST: 0.00 Byte (0 sectors)
	       Corrupted: 0.00 Byte (0 sectors)
	Slightly changed: 0.00 Byte (0 sectors)
	     Overwritten: 0.00 Byte (0 sectors)
```

Nosso resultado: **1,70 TB** (disco inteiro, ext4) com zero em tudo. Quaisquer valores diferentes de zero em `Corrupted`/`Slightly changed`/`Overwritten` indicam problema: não use o disco para dados importantes.

> A velocidade que o `f3read` mostra (nós vimos 1,26–1,57 GB/s) **não é um benchmark**. O limite do nosso slot era Gen3 (8 GT/s).

## 4. Desativar a economia de energia profunda (APST)

O autor do projeto upstream relata que o IG5236 trava em estados de baixo consumo e que o APST volta a ficar ativo a cada reinício. Não sabemos se isso teve relação com o nosso travamento original; adotamos como precaução.

**Linux (permanente):**

```bash
./scripts/linux/09-desativar-apst.sh
sudo reboot
cat /proc/cmdline | tr ' ' '\n' | grep nvme_core
cat /sys/module/nvme_core/parameters/default_ps_max_latency_us    # deve dar 0
sudo nvme get-feature /dev/nvme0 -f 0x0c -H | head -3             # APSTE: Disabled
```

> `sudo nvme set-feature /dev/nvme0 -f 0x0c -v 0` dá `Invalid Field in Command`: o comando enviou um valor sem a tabela de dados que a feature exige. **Não é problema** (e é desnecessário se o parâmetro do kernel está ativo).

**Windows:** no plano de energia ativo, em Opções avançadas → PCI Express → "Gerenciamento de energia de estado de vínculo", defina **Desativado**. Não validamos o efeito desse ajuste nesse controlador.

## 5. Backup e monitoramento

- **Mantenha backup** do que for importante. Não sabemos por que o disco falhou, e a causa pode voltar.
- Olhe o SMART de vez em quando:
  ```bash
  sudo nvme smart-log /dev/nvme0 | grep -E "critical|media|num_err|percentage|temperature|unsafe"
  ```
  O que importa: `critical_warning`, `media_errors`, `num_err_log_entries` em zero.
- No Windows: CrystalDiskInfo.

## 6. Se o disco voltar a `MN-5236`

Você já tem o procedimento: refaça do passo 7 do [`03-linux-passo-a-passo.md`](03-linux-passo-a-passo.md). **Guarde** a pasta `firmware/` e o `vendor/`. Se acontecer com frequência, o SSD provavelmente tem um problema de raiz (NAND ou controlador): considere a garantia ou a troca.

## 7. Usar o disco

- Para **Linux**: monte pelo UUID no `/etc/fstab` (`sudo blkid`).
- Para **Windows**: o instalador cria as partições. Se for só um disco de dados, inicialize como **GPT** no Gerenciamento de Disco.
