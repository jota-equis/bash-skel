#!/usr/bin/env bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
# · ---
SYS_LANG="${1:-es_ES}"
SSH_PORT=22
MASTER=
TOKEN=
REPO="https://raw.githubusercontent.com/jota-dev-src/bash-skel/main/k8s";
LPART=$(findfs LABEL=LOCAL_DATA)
# · ---
echo -e "| CLOUD-FINISH ... :: start :: ..."
# · ---
mkdir -pm0751 /srv/{backup,data,local} /var/lib/{docker,longhorn} /mnt/tmp;

if [[ ! -z "${LPART}" ]]; then
    mount ${LPART} /mnt/tmp; cd /mnt/tmp;

    btrfs subvolume create docker && chmod 0711 docker && mount /var/lib/docker;
    btrfs subvolume create data && chmod 0751 data && mount /srv/data;
    btrfs subvolume create longhorn && chmod 0751 longhorn && mount /var/lib/longhorn;

    mkdir -pm0751 /srv/local/{bin,etc};

    umount /mnt/tmp;
fi

curl -o /etc/apt/apt.conf.d/999-local ${REPO}/node/etc/apt/apt.conf.d/999-local;
curl -o /etc/fail2ban/jail.d/sshd.conf ${REPO}/node/etc/fail2ban/jail.d/sshd.conf;
curl -o /etc/fail2ban/jail.d/portscan.conf ${REPO}/node/etc/fail2ban/jail.d/portscan.conf;
curl -o /etc/ssh/sshd_config ${REPO}/node/etc/ssh/sshd_config && chmod 0600 /etc/ssh/sshd_config;
curl -o /etc/sysctl.d/999-local.conf ${REPO}/node/etc/sysctl.d/999-local.conf;
curl -o /etc/systemd/timesyncd.conf ${REPO}/node/etc/systemd/timesyncd.conf;
curl -o /srv/local/bin/k8n-firewall.sh ${REPO}/node/bin/k8n-fw-hcloud.sh && chmod 0750 /srv/local/bin/k8n-firewall.sh;

sed -i 's/^#force_color_prompt/force_color_prompt/g' /etc/skel/.bashrc;
sed 's/^Options=/Options=noexec,/g' /usr/share/systemd/tmp.mount > /etc/systemd/system/tmp.mount;

if [[ "x${SSH_PORT}" != "x22" ]]; then
    sed -i "/^Port 22/a Port ${SSH_PORT}" /etc/ssh/sshd_config;
    sed -i "s/^port = 22$/&,${SSH_PORT}/" /etc/fail2ban/jail.d/sshd.conf;
    sed -i "/^SSH_PORT=/c\SSH_PORT=${SSH_PORT}" /srv/local/bin/k8n-firewall.sh;
fi

[[ ! -z "${TOKEN}" ]] && sed -i "/^TOKEN=/c\TOKEN=${TOKEN}" /srv/local/bin/k8n-firewall.sh;
[[ ! -z "${DOMAIN}" ]] && sed -i "s/^#kernel.domainname/kernel.domainname           = ${DOMAIN}/g" /etc/sysctl.d/999-local.conf;

localectl set-locale LANG=${SYS_LANG}.UTF-8 LANGUAGE=${SYS_LANG} LC_MESSAGES=POSIX LC_COLLATE=C;
systemctl restart systemd-timesyncd.service;
systemctl enable tmp.mount && systemctl start tmp.mount;
systemctl enable fail2ban;
sync;
# · ---
#cron
# · ---
echo -e "| CLOUD-FINISH ... :: end :: ..."

exit 0
