#!/usr/bin/env bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
# · ---
PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH;
# · ---
VERSION=1.5
# · ---
MASTER="${1}";
TOKEN="${2}";
SSH_PORT="${3:-22}";
ROLE="${4}";
# · ---
BFIL="node.ip-addr"
LBEL="node.lan";

EDIR=/srv/local/etc/.env
BDIR=/srv/local/etc/firewall
FCUR="${BDIR}/${BFIL}.cur"
FNEW="${BDIR}/${BFIL}.new"
# · ---
[[ -d "${BDIR}" ]] || mkdir -pm0751 "${BDIR}"; cd "${BDIR}";
[[ -z "${TOKEN}" ]] && { echo -n "\nToken not provided! Can't continue ...\n"; exit 1; }
[[ -z "${ROLE}" && -f "${EDIR}/ROLE" ]] && ROLE="$(cat "${EDIR}/ROLE")";
[[ -z "${MASTER}" && -f "${EDIR}/MASTER" ]] && MASTER="$(cat "${EDIR}/MASTER")";
# · ---
[[ $(command -v jq) ]] || apt -y install jq
# · ---
APIU="https://api.hetzner.cloud/v1/servers"
APIH="Accept: application/json"
APIT="Authorization: Bearer"
APIQ=".servers[].public_net.ipv4.ip"

APIR="$(curl -H "${APIH}" -H "${APIT} ${TOKEN}" "${APIU}")";
# · ---
RSET=1
LAN=""
WAN=$(ip -4 -f inet a s eth0 | grep -Po 'inet \K[\d.]+')
NIL="$(find /sys/class/net -type l -not -name eth0 -not -lname '*virtual*' -printf '%f')" # Lan iface

echo -n "${APIR}" | jq -r "${APIQ}" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort -bu | sed -e "/${WAN}/d" > "${FNEW}";

if [[ -s "${FNEW}" ]]; then
    [[ -f "${FCUR}" ]] && cmp --silent "${FCUR}" "${FNEW}" && { rm -f ${FNEW}; echo -e "| K8n :: Firewall has no changes"; exit 0; }
    RSET=0
fi

UFW="$(ufw status numbered)"

declare -a NEW=( $(cat ${FNEW}) )
declare -a RUL=( $(echo -n "${UFW}" | awk -v a="# node.lan" '$0~a{ sub(/\[/, "")sub(/\]/, ""); { print $1 } }' | sort -brun) )
declare -a WLIST_NET=( "10.0.0.0/16" "10.42.0.0/16" "10.43.0.0/16" );

# · ---
if [[ "${UFW}" == "Status: inactive" || ${RSET} == 1 ]]; then
    ufw --force reset;

    ufw default deny incoming;
    ufw default allow outgoing;

    ufw allow in on lo comment 'base.fw · LOOPBACK.nic';

    if [[ ! -z "$NIL" ]]; then
        LAN=$(ip -4 -f inet a s ${NIL} | grep -Po 'inet \K[\d.]+')
#        ufw allow in on "${NIL}" comment 'base.fw · LOCAL.nic';
    fi

    ufw allow in on docker0 comment 'base.fw · DOCKER.nic';

    ufw allow from 127.0.0.0/8 comment 'base.fw · LOOPBACK.lan';
    ufw allow from 172.0.0.0/8 comment 'base.fw · DOCKER.lan';
    ufw allow from ff02::/8 comment 'base.fw · K8S-Vx.lan';

    for i in "${WLIST_NET[@]}"; do
        #ufw allow in from "${i}" comment 'base.fw · LOCAL.lan';
        ufw allow from "${i}" to "${LAN}" comment 'base.fw · LOCAL.lan';
    done
    
    # ufw allow in to "${LAN}" comment 'base.fw · LOCAL.lan';

    [[ -z "${MASTER}" ]] || ufw allow from "${MASTER}" comment "base.fw · Master.node";

    ufw allow in from any to "${WAN}" port 123 proto udp comment 'base.fw · NTP'
    
    ufw limit from any to ${WAN:-any} port ${SSH_PORT} proto tcp comment 'sys.fw · SSH';

    if [[ "${ROLE}" == "worker" ]]; then
        ufw allow 80/tcp comment 'srv.fw · HTTP';
        ufw allow 443/tcp comment 'srv.fw · HTTPS';
        ufw allow 30000:32767/tcp comment 'srv.fw · PODS';
    fi

    # if [[ "${EXTRAPORTS}" ]]

    ufw --force enable;
fi

for i in "${RUL[@]}"; do yes | ufw delete ${i} &> /dev/null; done;
for i in "${NEW[@]}"; do [[ ! -z "${i}" ]] && ufw allow from "${i}/32" comment "${LBEL}"; done;

mv ${FNEW} ${FCUR} && rm -f ${FRUL};

ufw reload;
# · ---
echo -e "| K8n :: Firewall rules updated"
# · ---
exit 0
