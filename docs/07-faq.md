# 07 — Perguntas frequentes

**Isso recupera os meus dados?**
Não. O procedimento reinicializa o SSD. Se os dados são insubstituíveis, procure um laboratório de recuperação **antes**, e pergunte por escrito se eles atendem o InnoGrit IG5236 em ROM mode. Um laboratório que estudou esse controlador afirma que ele usa criptografia sempre ativa, com chave presa ao controlador (informação de um site comercial, não verificada por nós) e que o suporte nos equipamentos profissionais é limitado.

**Por que o SSD aparece com 2 GB e o nome `MN-5236`?**
É o ROM mode: o controlador não conseguiu carregar o firmware que fica na NAND e responde com uma identidade mínima de fábrica. O "2 GB" é um espaço virtual vazio: lemos os 2 GiB inteiros e eram todos zeros. Seus dados não estão ali.

**Por que isso aconteceu com o meu disco?**
Não sabemos. No nosso caso houve travamentos antes e uma falha durante uma instalação de 130 GB. Um comentário sem fonte, num fórum, diz que o IG5236 sofre uma falha de firmware sob carga mista. Não verificamos.

**Funciona com outras marcas/modelos?**
Pode funcionar com qualquer SSD **InnoGrit IG5236** em ROM mode, mas **testamos só um Netac NV7000 2 TB**. Outras marcas (ADATA, Fanxiang, Ant Esports…) usam pacotes de firmware específicos. Se o seu controlador **não** é InnoGrit (`lspci -nn` com vendor `1dbe`), este guia não serve.

**Funciona no NV7000 de 1 TB? E no NV7000-T?**
O NV7000 de 1 TB tem relatos de fórum de sucesso com o mesmo pacote `3.S.J.11` (via MPUtility). O **NV7000-T** usa outro controlador (Maxio MAP1602): **não** é coberto por este guia.

**Posso usar um adaptador USB para NVMe?**
Para o método Linux deste repositório, **não**: o acesso é direto pelo barramento PCIe, via VFIO. Use o slot M.2 da placa ou um adaptador PCIe. Para o MPUtility, os relatos de sucesso também foram em slot direto.

**Por que não usar o `megaflash4` do projeto upstream direto?**
Porque ele não tem pontos de parada nem verificação de arquivos, e tem as esperas que descrevemos em [`09-como-funciona.md`](09-como-funciona.md) (mexer no `CC` depois do loader, o que derrubou o loader no nosso hardware). Nossa ferramenta (`tools/guided_flash.py`) usa o `netac_pipeline.py` do upstream como biblioteca e muda esse fluxo.

**O que é "hold"?**
Se algo falha, o script **não sai**: mantém o dispositivo aberto e espera você apertar Enter. Isso importa porque o dispositivo morre quando o processo que o segura termina (veja [`08-solucao-de-problemas.md`](08-solucao-de-problemas.md)). Use esse tempo para olhar `lspci` e `dmesg` em outro terminal.

**Quanto tempo leva?**
A gravação leva uns 5 a 10 minutos (o loader sozinho pode levar ~80 s só para responder). O resto é preparação, leitura e testes.

**O SSD vai durar?**
Não sabemos. O teste F3 de disco inteiro passou, o SMART está limpo, mas isso não prediz a vida do disco. Mantenha backup.

**O que fazer se alguma etapa falhar?**
Não repita nada às cegas. Guarde o log (`logs/`), e veja [`08-solucao-de-problemas.md`](08-solucao-de-problemas.md). O corte total de energia devolve o SSD ao ROM mode em todos os casos que vimos (nada se perdeu no ROM mode).

**Posso rodar isso em máquina virtual?**
Não testamos. O método precisa de acesso direto ao dispositivo PCIe (passthrough VFIO) e IOMMU; não é um caminho simples.

**Dá para fazer só com WSL no Windows?**
Não. O WSL2 não expõe dispositivos PCIe para o Linux. Use um pendrive Live ([`05-windows-via-linux-live.md`](05-windows-via-linux-live.md)).

**Posso confiar nos hashes do repositório?**
Eles são os da **nossa cópia** do pacote; o site de origem não publica hash oficial. Servem para detectar download corrompido e extração falha, não para garantir autenticidade.

**Posso distribuir os `.fw`?**
Não neste repositório: pertencem aos titulares, e o `.gitignore` os exclui.
