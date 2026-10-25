#!/usr/bin/env python3
"""Confere existencia, tamanho e SHA-256 dos arquivos de firmware descritos em um pacote JSON.
Somente leitura. Uso: python3 tools/verificar_firmware.py [firmware/pacote-3SJ11.json]"""
import hashlib, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
pacote = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "firmware", "pacote-3SJ11.json")
fw_dir = os.environ.get("NETAC_FW_DIR", os.path.dirname(os.path.abspath(pacote)))

with open(pacote) as f:
    pk = json.load(f)

print(f"Pacote: {pk['nome']}")
print(f"NAND: {pk['nand']}  |  pasta: {os.path.join(fw_dir, pk['pasta'])}\n")
tudo_ok = True
for chave in ("loader", "programmer", "rdisk"):
    item = pk[chave]
    caminho = os.path.join(fw_dir, pk["pasta"], item["arquivo"])
    if not os.path.isfile(caminho):
        print(f"[FALTANDO ] {chave}: {item['arquivo']}")
        tudo_ok = False
        continue
    dados = open(caminho, "rb").read()
    tam_ok = len(dados) == item["tamanho_bytes"]
    h = hashlib.sha256(dados).hexdigest()
    hash_ok = h == item["sha256"]
    estado = "OK       " if (tam_ok and hash_ok) else "DIVERGENTE"
    print(f"[{estado}] {chave}: {item['arquivo']}")
    print(f"            tamanho {len(dados)} (esperado {item['tamanho_bytes']}) | sha256 {h}")
    if h == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855":
        print("            ATENCAO: este e o hash de um arquivo VAZIO (extracao falhou; use unrar, nao 7z).")
    tudo_ok = tudo_ok and tam_ok and hash_ok

print("\nResultado:", "TUDO CONFERE" if tudo_ok else "HA PROBLEMAS - nao prossiga")
sys.exit(0 if tudo_ok else 1)
