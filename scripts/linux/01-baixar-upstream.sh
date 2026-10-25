#!/usr/bin/env bash
# Baixa o projeto upstream (Egorich-print/netac-nv7000-recovery, licenca MIT) para vendor/.
# Nosso tools/guided_flash.py importa o netac_pipeline.py dele.
source "$(dirname "$0")/_common.sh"
URL="https://github.com/Egorich-print/netac-nv7000-recovery"
if [ -d "$UPSTREAM/.git" ]; then
    aviso "$UPSTREAM ja existe. Nao vou atualizar (um 'git pull' pode mudar o comportamento)."
else
    git clone "$URL" "$UPSTREAM" || die "Falha no git clone."
fi
COMMIT="$(git -C "$UPSTREAM" rev-parse HEAD)"
echo "$COMMIT" > "$LOG_DIR/upstream-commit.txt"
ok "Upstream em $UPSTREAM (commit $COMMIT)."
info "Commit registrado em logs/upstream-commit.txt. Se um dia o upstream mudar e algo quebrar:"
info "  git -C vendor/netac-nv7000-recovery checkout $COMMIT"
[ -f "$UPSTREAM/tools/recovery/netac_pipeline.py" ] || die "netac_pipeline.py nao encontrado no upstream."
