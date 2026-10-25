# 10 — Relatar o seu resultado

Cada relato (sucesso **ou** falha) ajuda quem vier depois, principalmente com **outros modelos, outras NANDs e outros pacotes**, que não testamos. Abra uma *issue* usando este modelo.

```markdown
## Resultado
- [ ] Recuperado   - [ ] Falhou   - [ ] Parcial (descreva)

## Disco
- Marca/modelo:
- PN do adesivo:           (ex.: NT01NV7000-2T0-E4X)
- Mês/ano do QC:
- Controlador (marcação):  (ex.: INNOGRIT IG5236CAA)
- NAND (marcação):         (ex.: NTEF04TY... / Micron / H25...)
- Capacidade esperada:

## Sintoma original
- Como falhou, e há quanto tempo:

## Método
- [ ] Linux (este repositório)  - [ ] Windows MPUtility  - [ ] Windows via Linux Live
- Pacote de firmware usado (tag e hash do .rar):
- Commit do upstream (logs/upstream-commit.txt):

## Ambiente
- Distro e kernel (uname -r):
- Placa-mãe / CPU:
- Slot M.2 (Gen3/Gen4):

## O que aconteceu
- Tempo até o Identify pós-loader (linha "[pos-loader] Identify ... apos X s"):
- mpinfo (fabricante decodificado):
- Identidade depois do programmer:
- Identidade depois do corte de energia:
- Resultado do F3 (rapido/completo):
- SMART depois (critical_warning / media_errors / percentage_used):

## Logs
(anexe logs/run-*.log e logs/diagnostico-*.txt, SEM o número de série se preferir)
```
