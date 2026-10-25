#!/usr/bin/env python3
"""Fluxo guiado de recuperacao de SSD InnoGrit IG5236 (ROM mode "MN-5236", ~2 GB) em UM UNICO PROCESSO.

Uso (como root, normalmente via scripts/linux/05-check.sh e 06-run.sh):
  guided_flash.py check   -> so leitura
  guided_flash.py run     -> loader -> programmer -> DDR/mpinfo -> etapa destrutiva, com confirmacoes

Pontos importantes aprendidos na pratica (veja docs/09-como-funciona.md):
  - Loader e programmer sao confirmados JUNTOS no inicio: o controlador volta ao ROM se ficar parado.
  - Depois de um commit o script NAO toca no CC (limpar CC.EN reinicia o controlador e derruba o loader):
    manda UM Identify e espera a resposta (o loader pode levar ~80 s).
  - Em qualquer falha o script NAO sai: mantem o dispositivo aberto (hold), porque o dispositivo morre
    quando o processo que o segura termina.
Este arquivo depende do netac_pipeline.py do projeto upstream (MIT), baixado em vendor/."""
import hashlib, json, os, select, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FW_DIR = os.environ.get("NETAC_FW_DIR", os.path.join(ROOT, "firmware"))
UPSTREAM = os.environ.get("NETAC_UPSTREAM", os.path.join(ROOT, "vendor", "netac-nv7000-recovery"))
PACOTE = os.environ.get("NETAC_PACOTE", os.path.join(FW_DIR, "pacote-3SJ11.json"))
os.environ["NETAC_FW_DIR"] = FW_DIR
os.environ.setdefault("NETAC_QSIZE", "2")
sys.path.insert(0, os.path.join(UPSTREAM, "tools", "recovery"))
try:
    import netac_pipeline as P
except ImportError as e:
    print(f"Nao consegui importar netac_pipeline de {UPSTREAM}/tools/recovery ({e}).")
    print("Rode scripts/linux/01-baixar-upstream.sh ou defina NETAC_UPSTREAM.")
    sys.exit(2)
for _nome in ("VfioCdev", "Nvme", "flash_file", "cmfg_conf_page", "MAGIC_GRIT",
              "MAGIC_INNO", "BUF_OFF", "REG_CC", "REG_CSTS", "CDEV"):
    if not hasattr(P, _nome):
        print(f"O netac_pipeline.py do upstream nao tem '{_nome}'. O projeto upstream mudou.")
        print("Use o commit registrado em logs/upstream-commit.txt (git checkout <commit>).")
        sys.exit(2)

try:
    with open(PACOTE) as _f:
        PK = json.load(_f)
except (OSError, ValueError) as e:
    print(f"Nao consegui ler o descritor do pacote de firmware ({PACOTE}): {e}")
    sys.exit(2)

M2 = os.path.join(FW_DIR, PK["pasta"])
LOADER = PK["loader"]["arquivo"]
PROG = PK["programmer"]["arquivo"]
RDISK = PK["rdisk"]["arquivo"]
SHA = {
    LOADER: PK["loader"]["sha256"],
    PROG: PK["programmer"]["sha256"],
    RDISK: PK["rdisk"]["sha256"],
}
MFR = {0x9B: "YMTC", 0x2C: "Micron", 0xAD: "SK hynix", 0xEC: "Samsung",
       0x98: "Kioxia/Toshiba", 0x45: "SanDisk"}
GRIT, INNO = P.MAGIC_GRIT, P.MAGIC_INNO
ALL1 = 0xFFFFFFFFFFFFFFFF


def path(n):
    return os.path.join(M2, n)


def verify():
    ok = True
    for n, want in SHA.items():
        if not os.path.isfile(path(n)):
            print("FALTANDO:", path(n)); ok = False; continue
        got = hashlib.sha256(open(path(n), "rb").read()).hexdigest()
        print(("OK            " if got == want else "HASH DIFERENTE ") + n)
        ok = ok and got == want
    return ok


def snap(nv):
    b = nv.b
    return (b.rd64(0), b.rd32(8), b.rd32(P.REG_CC), b.rd32(P.REG_CSTS))


def fmt(s):
    return f"CAP=0x{s[0]:016x} VS=0x{s[1]:08x} CC=0x{s[2]:08x} CSTS=0x{s[3]:08x}"


def wait_reset(nv, label, maxs=45):
    """Espera PASSIVA (sem escrever) o controlador se reiniciar sozinho."""
    t0 = time.time()
    last = None
    while time.time() - t0 < maxs:
        s = snap(nv)
        if s != last:
            print(f"[{label}] t={time.time() - t0:5.1f}s {fmt(s)}")
            last = s
        if s[0] == ALL1:
            print(f"[{label}] BAR0 passou a ler 0xFFFF... (dispositivo nao responde)")
            return "dead"
        if (s[2] & 1) == 0:
            time.sleep(2)
            return "reset"
        time.sleep(0.25)
    print(f"[{label}] o controlador nao se reiniciou em {maxs}s; seguindo mesmo assim")
    return "no-reset"


def identify_once(nv, label):
    """UM enable e UM Identify, com paciencia longa."""
    status, csts, dt = nv.enable(timeout=30)
    print(f"[{label}] enable -> {status} CSTS=0x{csts:08x} em {dt:.1f}s")
    if status != "ready":
        return None
    st = nv.admin(0x06, cdw10=1, nsid=0, prp1=nv.b.dev_addr(P.BUF_OFF), timeout=30)
    if st != 0:
        return None
    d = nv.b.read_mem(P.BUF_OFF, 4096)
    f = lambda a, b: d[a:b].decode("latin1").strip("\x00 ")
    ident = (f(4, 24), f(24, 64), f(64, 72))
    print(f"[{label}] SN={ident[0]!r} MN={ident[1]!r} FR={ident[2]!r}")
    return ident


def settle(nv, label, maxs=150):
    """Depois de um commit: NAO mexe no CC. Se o controlador se reiniciou sozinho (CC.EN=0),
    faz o enable completo; senao manda UM Identify e espera ate maxs segundos pela resposta."""
    time.sleep(3)
    s = snap(nv)
    print(f"[{label}] {fmt(s)}")
    if s[0] == ALL1:
        print(f"[{label}] BAR0 le 0xFFFF... (dispositivo nao responde)")
        return None
    if (s[2] & 1) == 0:
        print(f"[{label}] o controlador se reiniciou sozinho (CC.EN=0); enable completo")
        time.sleep(2)
        return identify_once(nv, label)
    t0 = time.time()
    st = nv.admin(0x06, cdw10=1, nsid=0, prp1=nv.b.dev_addr(P.BUF_OFF), timeout=maxs, verbose=False)
    dt = time.time() - t0
    s = snap(nv)
    print(f"[{label}] Identify sem tocar no CC -> status={st} apos {dt:.1f}s | {fmt(s)}")
    if st is None:
        if s[0] != ALL1 and (s[2] & 1) == 0:
            print(f"[{label}] o controlador se reiniciou durante a espera; enable completo")
            return identify_once(nv, label)
        return None
    d = nv.b.read_mem(P.BUF_OFF, 4096)
    f = lambda a, b: d[a:b].decode("latin1").strip("\x00 ")
    ident = (f(4, 24), f(24, 64), f(64, 72))
    print(f"[{label}] SN={ident[0]!r} MN={ident[1]!r} FR={ident[2]!r}")
    return ident


def show_mpinfo(d, label):
    if d is None:
        print(f"[{label}] mpinfo: sem resposta"); return
    out = os.path.join(FW_DIR, f"mpinfo_{label}.bin")
    with open(out, "wb") as f:
        f.write(d)
    print(f"[{label}] mpinfo salvo em {out} | bytes nao-zero: {sum(1 for b in d if b)}/4096")
    print("  primeiros 64 bytes:", d[:64].hex())
    achou = 0
    for i in range(64):
        e = d[0x24E + 6 * i: 0x24E + 6 * i + 6]
        if len(e) < 6 or e in (b"\x00" * 6, b"\xff" * 6):
            continue
        achou += 1
        print(f"  entrada {i:02d}: {e.hex()}  fabricante: {MFR.get(e[0], 'desconhecido')}")
    if not achou:
        print("  nenhuma entrada de NAND em 0x24E (offset vem do projeto ssd-flash-id; nao verificado neste disco)")


def hold(nv, msg):
    print("\n" + msg)
    print("Processo mantido ABERTO. Em outro terminal: lspci -nn -s 01:00.0 ; dmesg | tail")
    print("Aperte Enter aqui para encerrar (isso fecha o dispositivo VFIO).")
    last = None
    while True:
        r, _, _ = select.select([sys.stdin], [], [], 5)
        if r:
            sys.stdin.readline()
            break
        s = snap(nv)
        if s != last:
            print(f"  [hold] {fmt(s)}")
            last = s
    sys.exit(3)


def gate(texto, frase):
    print("\n" + "=" * 64 + "\n" + texto)
    r = input(f"Para continuar, digite exatamente {frase} (Enter aborta): ").strip()
    if r != frase:
        print("Abortado."); sys.exit(0)


def gate_alive(nv, texto, frase):
    """Como gate(), mas manda um mpinfo (so leitura) a cada 3 s para manter o controlador ativo."""
    print("\n" + "=" * 64 + "\n" + texto)
    print(f"Digite exatamente {frase} e Enter (Enter vazio aborta). Keepalive ativo.")
    falhas = 0
    while True:
        r, _, _ = select.select([sys.stdin], [], [], 3)
        if r:
            resp = sys.stdin.readline().strip()
            if resp != frase:
                hold(nv, "Abortado pelo usuario; nada alem do loader foi gravado.")
            return
        d = nv.get_mpinfo(0, verbose=False)
        if d is None:
            falhas += 1
            print(f"  [keepalive] sem resposta ({falhas})")
            if falhas >= 2:
                hold(nv, "O controlador parou de responder enquanto esperava a confirmacao.")
        else:
            falhas = 0


def is_prog(ident):
    return "INNOGRIT" in ident[1] or "SSD-DRAM" in ident[0]


def download_nsid0(nv, data, label):
    off = 0
    while off < len(data):
        part = data[off:off + 4096]
        nv.b.zero_mem(P.BUF_OFF, 4096)
        nv.b.write_mem(P.BUF_OFF, part)
        st = nv.admin(0x11, cdw10=(len(part) - 1) >> 2, cdw11=off >> 2, nsid=0,
                      prp1=nv.b.dev_addr(P.BUF_OFF), timeout=15, verbose=False)
        if st != 0:
            print(f"  [{label}] chunk #{off // 4096} status={st}")
            return False
        if off % (4096 * 64) == 0:
            print(f"  [{label}] chunk #{off // 4096} ok")
        off += len(part)
    print(f"  [{label}] download ok ({len(data)} bytes)")
    return True


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode not in ("check", "run"):
        print("uso: guided_flash.py [check|run]"); sys.exit(1)
    if os.geteuid() != 0:
        print("rode com sudo"); sys.exit(1)
    if not verify():
        print("Arquivos ausentes ou com hash diferente. Nada foi enviado ao SSD."); sys.exit(2)

    be = P.VfioCdev(P.CDEV)
    nv = P.Nvme(be)
    print(f"estado inicial: {fmt(snap(nv))}")
    if snap(nv)[0] == ALL1:
        print("BAR0 ja le 0xFFFF...: faca um desligamento completo da energia antes de tentar.")
        sys.exit(2)
    ident = identify_once(nv, "inicio")
    if not ident:
        print("sem identidade no inicio. Nada foi gravado."); sys.exit(3)
    rom = "MN-5236" in ident[1] or "SSD-5236" in ident[0]
    if mode == "check":
        print(f"\nModo check: nada foi gravado. ROM mode: {rom}")
        return

    alive = False  # True se o controlador responde mpinfo na sessao atual, depois do loader

    # ---- etapa 1: ToRecovery + loader ----
    if rom:
        gate("ETAPAS 1 e 2 (SEM PAUSA ENTRE ELAS): ToRecovery (0xF7), GRAVAR loader.fw e depois\n"
             "GRAVAR programmer+cust+3SJ11+ymtcx2.fw (pacote para NAND YMTC).\n"
             "O controlador volta ao ROM se ficar parado entre as duas etapas, entao nao ha como pausar.\n"
             "Se a NAND nao for YMTC, o disco pode sumir do barramento.\n"
             "Evidencia: marcacao NTEF na NAND, PN e data do QC (nao e prova).\n"
             "A etapa destrutiva (BrandNew/rdisk) so ocorre depois, com outra confirmacao.",
             "GRAVAR LOADER E PROGRAMMER")
        nv.enable(timeout=20)
        print("ToRecovery:", nv.to_recovery())
        time.sleep(2)
        if not P.flash_file(nv, path(LOADER)):
            hold(nv, "FALHOU a gravacao do loader.")
        print("\n[pos-loader] SEM mexer no CC: um unico Identify, esperando ate 150 s pela resposta...")
        ident = settle(nv, "pos-loader", maxs=150)
        if ident is None:
            hold(nv, "Sem resposta depois do loader.")

    # ---- etapa 2: programmer ----
    if not is_prog(ident):
        print("\nETAPA 2 (sem pausa; ja confirmada no inicio): gravando programmer+cust+3SJ11+ymtcx2.fw")
        if not P.flash_file(nv, path(PROG)):
            hold(nv, "FALHOU a gravacao do programmer.")
        ident = settle(nv, "pos-programmer", maxs=150)
        if not ident or not is_prog(ident):
            hold(nv, "Sem identidade de programmer depois do commit (veja o log).")

    # ---- DDR + mpinfo ----
    nv.enable(timeout=20)
    print("DDR eye:", nv.admin(0xE4, cdw12=3, cdw14=GRIT, cdw15=INNO, timeout=30))
    time.sleep(5)
    d = None
    for _ in range(12):
        d = nv.get_mpinfo(0, verbose=False)
        if d and any(d):
            break
        time.sleep(5)
    show_mpinfo(d, "pos_programmer")

    # ---- etapa 3: destrutiva ----
    gate_alive(nv, "ETAPA 3 (SEM VOLTA): BrandNew + RemoveCheck, gravar rdisk, CONF, commit 0x19,\n"
         "SmartClean e BrandNew final. Todos os dados antigos serao perdidos.\n"
         "Confira acima o fabricante da NAND (0x9B = YMTC) antes de continuar.",
         "APAGAR E GRAVAR RDISK")
    nv.enable(timeout=20)
    print("BrandNew:", nv.admin(0xE4, cdw12=1, cdw14=GRIT, cdw15=INNO, timeout=60))
    print("RemoveCheck:", nv.admin(0xE4, cdw12=5, cdw14=GRIT, cdw15=INNO, timeout=60))
    time.sleep(2)
    data = open(path(RDISK), "rb").read()
    nv.enable(timeout=20)
    if not download_nsid0(nv, data, "rdisk"):
        hold(nv, "FALHOU o download do rdisk.")
    conf = None
    if data[:4] == b"CMFG":
        conf, _ = P.cmfg_conf_page(data)
    if conf:
        print("CONF 0xE5:", nv.set_fwconfig(conf))
    time.sleep(3)
    st = nv.admin(0x10, cdw10=0x19, nsid=0, timeout=180)
    print("commit 0x19 ->", st)
    if st != 0:
        hold(nv, "FALHOU o commit do rdisk.")
    wait_reset(nv, "pos-rdisk", maxs=60)
    print("pos-rdisk:", identify_once(nv, "pos-rdisk"))
    try:
        nv.enable(timeout=20)
        print("SmartClean:", nv.admin(0xD0, cdw14=GRIT, cdw15=INNO, timeout=60))
        print("BrandNew:", nv.admin(0xE4, cdw12=1, cdw14=GRIT, cdw15=INNO, timeout=60))
        print("IDENT FINAL:", identify_once(nv, "final"))
    except Exception as e:
        print("erro na finalizacao:", e)
    hold(nv, "FIM. AGORA: desligue o PC e corte a energia (chave da fonte) por ~30 s. "
             "Reiniciar NAO basta.")


if __name__ == "__main__":
    main()
