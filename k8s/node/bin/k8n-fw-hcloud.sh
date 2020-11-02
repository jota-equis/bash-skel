#!/usr/bin/env bash
VERSION=0.9

MASTER="${1}";
TOKEN="${2}";
SSH_PORT="${3:-22}";

BDIR=/srv/local/etc/firewall
BFIL="node.ip-addr"
LBEL="node.lan";
LLAN="10.0.1.0/16"      # Local lan
PLAN="10.42.0.0/16"     # Pods lan
CLAN="10.43.1.0/16"     # Clusters lan
# · ---
[[ -z "${TOKEN}" ]] && { echo -e "\nToken not provided! Can't continue ...\n"; exit 1; }
[[ $(command -v jq) ]] || apt -y install jq
[[ -d "${BDIR}" ]] || mkdir -pm0751 "${BDIR}"
cd "${BDIR}"

WAN=$(ip -4 -f inet a s eth0 | grep -Po 'inet \K[\d.]+')
NIL="$(find /sys/class/net -type l -not -name eth0 -not -lname '*virtual*' -printf '%f')" # Lan iface
[[ -z "${NIL}" ]] && LAN="" || LAN=$(ip -4 -f inet a s ${NIL} | grep -Po 'inet \K[\d.]+')

FCUR="${BDIR}/${BFIL}.cur"
FNEW="${BDIR}/${BFIL}.new"
FRUL="${BDIR}/${BFIL}.rul"

APIU="https://api.hetzner.cloud/v1/servers"
APIH="Accept: application/json"
APIT="Authorization: Bearer"
APIQ=".servers[].public_net.ipv4.ip"

UFW="$(ufw status numbered)"
# · ---
if [[ "${UFW}" == "Status: inactive" ]]; then
    ufw --force reset;
    ufw default deny incoming;
    ufw default deny outgoing;
    ufw default allow routed;
    # forwarding ?

    # [[ -z "$MASTER" ]] || ufw allow from ${MASTER} to ${IP_WAN:-any} comment "Master"

    ufw limit proto tcp from any to ${WAN:-any} port ${SSH_PORT};

    ufw allow in on lo comment 'base.fw · LOOPBACK'
    ufw allow out on lo comment 'base.fw · LOOPBACK'

    if [[ ! -z "$NIL" ]]; then
        ufw allow in on "${NIL}" comment 'base.fw · LAN'
        ufw allow out on "${NIL}" comment 'base.fw · LAN'
    fi

    ufw allow in on docker0 comment 'base.fw · DOCKER'
    ufw allow out on docker0 comment 'base.fw · DOCKER'

    ufw allow from "${LLAN}" comment 'base.fw · PRIVATE'
    ufw allow in from "${PLAN}" to "${PLAN}" comment 'base.fw · K8S-PODS'
    ufw allow out to "${PLAN}" comment 'base.fw · K8S-PODS'
    ufw allow from "${CLAN}" comment 'base.fw · K8S-CLUSTERS'

    ufw allow out from "${WAN}" to any port 53 proto udp comment 'base.fw · DNS'
    ufw allow out from "${WAN}" to any port 53 proto tcp comment 'base.fw · DNS'
    ufw allow out from "${WAN}" to any port 80 proto tcp comment 'base.fw · HTTP'
    ufw allow out from "${WAN}" to any port 123 proto udp comment 'base.fw · NTP'
    ufw allow in from any to "${WAN}" port 123 proto udp comment 'base.fw · NTP'
    ufw allow out from "${WAN}" to any port 443 proto tcp comment 'base.fw · HTTPS'
    ufw allow out from "${WAN}" to any port 853 proto tcp comment 'base.fw · DNS-TLS'
    ufw allow out from "${WAN}" to any port 11371 proto tcp comment 'base.fw · PGP-KEYSERVERS'
    ufw allow out from "${WAN}" to any port 11371 proto udp comment 'base.fw · PGP-KEYSERVERS'

    ufw --force enable

    UFW="$(ufw status numbered)"
fi

if [[ ! -f "${FCUR}" ]]; then
    echo "${UFW}" | awk -v a="${LBEL}" -v b="${FRUL}" -v c="${FCUR}" \
        '$0~a{ sub(/\/tcp/, "")sub(/\[/, "")sub(/\]/, ""); { print $1"@"$5 > b; print $5 } }' | \
        sort -u  > "${FCUR}";
fi

echo "$(curl -H "${APIH}" -H "${APIT} ${TOKEN}" "${APIU}" | jq -r "${APIQ}" | sort -u)" > "${FNEW}";

cmp --silent "${FCUR}" "${FNEW}" && exit 0; # No changes

[[ ! -f "${FRUL}" ]] && touch ${FRUL}

declare -a NEW=( $(cat ${FNEW}) )
declare -a RUL=( $(tac ${FRUL}) )

NEW=( "${NEW[@]/$WAN}" )

for I in "${RUL[@]}"; do
    IFS=@ read id addr <<< ${I}
    [[ " ${NEW[@]} " =~ " ${addr} " ]] && NEW=( "${NEW[@]/$addr}" ) || yes | ufw delete ${id} &> /dev/null
done

for I in "${NEW[@]}"; do
    if [[ ! -z "${I}" ]]; then
        ufw allow in from "${I}" to ${WAN:-any} comment "${LBEL}";
        ufw allow out to "${I}" from ${WAN:-any} comment "${LBEL}";
    fi
done

rm ${FRUL} && mv ${FNEW} ${FCUR}
# · ---
exit 0
