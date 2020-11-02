#!/usr/bin/env bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
# · ---
VERSION=1.05
# · ---
function verGet { [[ $# -gt 0 ]] && ( [[ -z "${2}" ]] && echo "${1}" || echo "$(cat ${1})" ) | grep -Po '^VERSION=\K[\d.]+$'; }
function verMax { printf '%s\n' "${1:-1}" "${2:-0}" | sort -g -r | head -1; }

# · ---
# FW
FW_PATH=/srv/local/bin/k8n-firewall.sh
FW_GIT="$(curl -s https://raw.githubusercontent.com/jota-dev-src/bash-skel/main/k8s/node/bin/k8n-fw-hcloud.sh)"
FW_VER="$(verGet ${FW_PATH} true)"

if [[ $(verMax "${FW_VER}" $(verGet "${FW_GIT}")) != "${FW_VER}" ]]; then
    echo "${FW_GIT}" >  "${FW_PATH}";

    if [[ -f "/srv/local/etc/.env/TOKEN" ]]; then
        TOKEN="$(cat /srv/local/etc/.env/TOKEN)"
        [[ -z "${TOKEN}" ]] || sed -i "/^TOKEN=/c\TOKEN=${TOKEN}" /srv/local/bin/k8n-firewall.sh;
    fi

    if [[ -f "/srv/local/etc/.env/SSH_PORT" ]]; then
        SSH_PORT="$(cat /srv/local/etc/.env/SSH_PORT)"
        [[ -z "${SSH_PORT}" ]] || sed -i "/^SSH_PORT=/c\SSH_PORT=${SSH_PORT}" /srv/local/bin/k8n-firewall.sh
    fi

    echo "| K8n:: FireWall Update";
fi

# · ---
exit 0
