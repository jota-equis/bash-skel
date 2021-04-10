#!/usr/bin/env bash
exec 1> >(logger -s -t $(basename $0)) 2>&1
# · ---
VERSION=1.64
# · ---
PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH;
# · ---
BFIL="node.ip-addr"
LBEL="node.lan";
# · ---
DIRCNF=/srv/local/etc
DIRENV=${DIRCNF}/.env
DIRFWL=${DIRCNF}/firewall
FCUR="${DIRFWL}/${BFIL}.cur"
FNEW="${DIRFWL}/${BFIL}.new"

[[ -d "${DIRFWL}" ]] || mkdir -pm0751 "${DIRENV}" "${DIRFWL}"; cd "${DIRFWL}";
# · ---
RSET=1
MASTER="${1:-$([[ -f "${DIRENV}/MASTER" ]] && cat "${DIRENV}/MASTER")}";
TOKEN="${2:-$([[ -f "${DIRENV}/TOKEN" ]] && cat "${DIRENV}/TOKEN")}";
SSH_PORT="${3:-$([[ -f "${DIRENV}/SSH_PORT" ]] && cat "${DIRENV}/SSH_PORT" || echo 22)}";
ROLE="${4:-$([[ -f "${DIRENV}/ROLE" ]] && cat "${DIRENV}/ROLE")}";
EXTRAPORTS="${5:-$([[ -f "${DIRENV}/EXTRAPORTS" ]] && cat "${DIRENV}/EXTRAPORTS" | sort -bun)}";
# · ---
WAN=$(ip -4 -f inet a s eth0 | grep -Po 'inet \K[\d.]+')
NIL="$(find /sys/class/net -type l -not -name eth0 -not -lname '*virtual*' -printf '%f')"

[[ ! -z "$NIL" ]] && LAN=$(ip -4 -f inet a s ${NIL} | grep -Po 'inet \K[\d.]+') || LAN="";
# · ---
[[ $(command -v jq) ]] || apt -y install jq;
# · ---
APIU="https://api.hetzner.cloud/v1/servers"
APIH="Accept: application/json"
APIT="Authorization: Bearer"
APIQ=".servers[].public_net.ipv4.ip"

APIR="$(curl -H "${APIH}" -H "${APIT} ${TOKEN}" "${APIU}")";
# · ---
UFW="$(ufw status numbered)"
echo -n "${APIR}" | jq -r "${APIQ}" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort -bu | sed -e "/${WAN}/d" > "${FNEW}";

if [[ -s "${FNEW}" ]]; then
    RSET=0;

    if [[ -f "${FCUR}" ]]; then
        cmp --silent "${FCUR}" "${FNEW}" && {
            [[ "${UFW}" == "Status: inactive" ]] && RSET=1 || rm -f ${FNEW}; echo -e "| K8n :: Firewall has no changes"; exit 0;
        }
    fi
fi

declare -a NEW=( $(cat ${FNEW}) )
declare -a RUL=( $(echo -n "${UFW}" | awk -v a="# node.lan" '$0~a{ sub(/\[/, "")sub(/\]/, ""); { print $1 } }' | sort -brun) )
declare -a WLIST_NET=( "10.0.0.0/16" );
# · ---
if [[ "${UFW}" == "Status: inactive" || ${RSET} == 1 ]]; then
    ufw --force reset;

    ufw default deny incoming;
    ufw default allow outgoing;

    ufw allow in on lo from 127.0.0.0/8 to 127.0.0.0/8 comment 'base.fw · LOOPBACK.lan';
    #ufw allow in on "${NIL:-any}" from 10.0.0.0/8 comment 'base.fw · LOCAL.lan'
    ufw allow from 10.0.0.0/16 comment 'base.fw · LOCAL.lan';
    ufw allow from 10.1.0.0/16 comment 'base.fw · LOCAL.lan';
    ufw allow from 10.42.0.0/16 comment 'base.fw · FLANNEL.lan';
    ufw allow from 10.43.0.0/16 comment 'base.fw · CALICO.lan';
    ufw allow from 10.244.0.0/16 comment 'base.fw · HCLOUD.lan';
    ufw allow from 172.0.0.0/8 comment 'base.fw · DOCKER.lan';
    ufw allow from ff02::/8 comment 'base.fw · K8S-Vx.lan';
#    for i in "${WLIST_NET[@]}"; do ufw allow in on "${NIL:-any}" from "${i}" to "${LAN:-any}" comment 'base.fw · LOCAL.lan'; done

    [[ -z "${MASTER}" ]] || ufw allow from "${MASTER}" comment "base.fw · Master.node";

    ufw allow in from any to "${WAN}" port 123 proto udp comment 'sys.fw · NTP'
    ufw limit from any to ${WAN:-any} port ${SSH_PORT} proto tcp comment 'sys.fw · SSH';

    if [[ "${ROLE}" == "worker" ]]; then
        ufw allow in from any to "${WAN}" port 80 comment 'srv.fw · HTTP';
        ufw allow in from any to "${WAN}" port 443 comment 'srv.fw · HTTPS';
        ufw allow in from any to "${WAN}" port 30000:32767 comment 'srv.fw · PODS';

        for i in "${EXTRAPORTS[@]}"; do [[ ! -z "${i}" ]] && ufw allow in from any to "${WAN}" port "${i}" proto tcp comment 'srv.fw · Port ${i}'; done
    fi

    ufw --force enable;
fi

for i in "${RUL[@]}"; do yes | ufw delete ${i} &> /dev/null; done;
for i in "${NEW[@]}"; do [[ ! -z "${i}" ]] && ufw allow from "${i}/32" to "${WAN}" comment "${LBEL}"; done;

mv ${FNEW} ${FCUR} && rm -f ${FRUL};

ufw reload;
# · ---
echo -e "| K8n :: Firewall rules updated"
# · ---
exit 0
