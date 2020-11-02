#!/usr/bin/env bash

# · ---
function verGet { [[ $# -gt 0 ]] && ( [[ -z "${2}" ]] && echo "${1}" || echo "$(cat ${1})" ) | grep -Po '^VERSION=\K[\d.]+$'; }
function verMax { printf '%s\n' "${1:-1}" "${2:-0}" | sort -g -r | head -1; }

# · ---
# FW
FW_PATH=/srv/local/bin/k8n-firewall.sh
FW_GIT="$(curl -s https://raw.githubusercontent.com/jota-dev-src/bash-skel/main/k8s/node/bin/k8n-fw-hcloud.sh)"
FW_VER="$(verGet ${FW_PATH} true)"

[[ $(verMax "${FW_VER}" $(verGet "${FW_GIT}")) == "${FW_VER}" ]] || echo "${FW_GIT}" >  "${FW_PATH}"

# · ---
exit 0
