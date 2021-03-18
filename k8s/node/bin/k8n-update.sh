#!/usr/bin/env bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
# · ---
VERSION=1.10
# · ---
function verGet { [[ $# -gt 0 ]] && ( [[ -z "${2}" ]] && echo "${1}" || echo "$(cat ${1})" ) | grep -Po '^VERSION=\K[\d.]+$'; }
function verMax { printf '%s\n' "${1:-1}" "${2:-0}" | sort -g -r | head -1; }
# · ---
# UPDATER
LOCAL_PATH=/srv/local/bin/k8n-update.sh
LOCAL_VER="$(verGet ${LOCAL_PATH} true)"
GIT_PATH="$(curl -s https://raw.githubusercontent.com/jota-dev-src/bash-skel/main/k8s/node/bin/k8n-update.sh)"

if [[ $(verMax "${LOCAL_VER}" $(verGet "${GIT_PATH}")) != "${LOCAL_VER}" ]]; then
    echo "${GIT_PATH}" >  "${LOCAL_PATH}";
    echo "| K8n:: Self Update. Reloading ...";
    sleep 1;
    ${LOCAL_PATH};
    exit  0;
fi
# · ---
# FW
LOCAL_PATH=/srv/local/bin/k8n-firewall.sh
LOCAL_VER="$(verGet ${LOCAL_PATH} true)"
GIT_PATH="$(curl -s https://raw.githubusercontent.com/jota-dev-src/bash-skel/main/k8s/node/bin/k8n-fw-hcloud.sh)"

if [[ $(verMax "${LOCAL_VER}" $(verGet "${GIT_PATH}")) != "${LOCAL_VER}" ]]; then
    echo "${GIT_PATH}" >  "${LOCAL_PATH}";
    echo "| K8n:: FireWall Update. Reloading ...";
    sleep 2;
    yes | ufw reset;
    sleep 1;
    ${LOCAL_PATH};
fi
# · ---
# CLOUD PROVIDER
LOCAL_PATH=/srv/local/bin/k8n-cloudprovider.sh
GIT_PATH="$(curl -s https://raw.githubusercontent.com/jota-dev-src/bash-skel/main/k8s/node/bin/k8n-cloudprovider.sh)"
LOCAL_VER="$(verGet ${LOCAL_PATH} true)"

if [[ $(verMax "${LOCAL_VER}" $(verGet "${GIT_PATH}")) != "${LOCAL_VER}" ]]; then
    echo "${GIT_PATH}" >  "${LOCAL_PATH}";
    echo "| K8n:: Cloud Provider Updated.";
    sleep 1;
fi
# · ---
# Docker clean
LOCAL_PATH=/srv/local/bin/k8n-docker_cleanup.sh
GIT_PATH="$(curl -s https://raw.githubusercontent.com/jota-dev-src/bash-skel/main/k8s/node/bin/k8n-docker_cleanup.sh)"
LOCAL_VER="$(verGet ${LOCAL_PATH} true)"

if [[ $(verMax "${LOCAL_VER}" $(verGet "${GIT_PATH}")) != "${LOCAL_VER}" ]]; then
    echo "${GIT_PATH}" >  "${LOCAL_PATH}";
    echo "| K8n:: Docker Cleaner Updated.";
    sleep 1;
fi
# · ---
exit 0
