#!/bin/sh
# Пароль ansible-vault: в CI из переменной ANSIBLE_VAULT_PASSWORD, локально из файла
set -eu

if [ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]; then
    printf '%s\n' "$ANSIBLE_VAULT_PASSWORD"
elif [ -r "$HOME/.ansible/audit-svc-vault-pass" ]; then
    cat "$HOME/.ansible/audit-svc-vault-pass"
else
    echo "vault-pass.sh: set ANSIBLE_VAULT_PASSWORD or create ~/.ansible/audit-svc-vault-pass" >&2
    exit 1
fi
