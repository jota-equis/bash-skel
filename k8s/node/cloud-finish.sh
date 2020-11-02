#!/usr/bin/env bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
# · ---
SYS_LANG="${1:-es_ES}"
SSH_PORT=22
MASTER=
TOKEN=
# · ---
DIR=/var/run/cloud-finish
# · ---
echo -e "| CLOUD-FINISH ... :: start :: ..."
# · ---
mkdir -pm0751 ${DIR}; cd ${DIR};

mkdir -pm0751 /srv/data /srv/backup /srv/local /var/lib/docker /var/lib/longhorn;
mount /dev/sda2 /srv/local

sed -i 's/^#Port 22/Port 22/g' /etc/ssh/sshd_config;
sed -i 's/^#force_color_prompt/force_color_prompt/g' /etc/skel/.bashrc;
sed 's/^Options=/Options=noexec,/g' /usr/share/systemd/tmp.mount > /etc/systemd/system/tmp.mount;

localectl set-locale LANG=${SYS_LANG}.UTF-8 LANGUAGE=${SYS_LANG} LC_MESSAGES=POSIX LC_COLLATE=C;
systemctl restart systemd-timesyncd.service;
systemctl enable tmp.mount && systemctl start tmp.mount;
systemctl enable fail2ban;

https://raw.githubusercontent.com/jota-dev-src/bash-skel/main/k8s/node/bin/fw-hcloud.sh
# · ---
