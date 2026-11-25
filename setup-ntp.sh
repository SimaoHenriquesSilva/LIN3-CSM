#!/bin/bash
# ===== À MODIFIER SELON LE SITE =====
HOST=NTP-SRV-LIN
TZ_NAME=Europe/Zurich                  # fuseau horaire du serveur
NTP_SERVERS=""       
NTP_POOL="ie.pool.ntp.org"             # pool NTP irlandais ; vide = pas de pool
POOL_MAX=4                             # nb max de sources prises dans le pool (ignoré si NTP_POOL vide) ; total = serveurs fixes + POOL_MAX
# ====================================
# Hostname (+ /etc/hosts, + cloud-init pour que ça survive au reboot)
[ "$(hostname)" = "$HOST" ] || hostnamectl set-hostname "$HOST"
grep -q "^127.0.1.1 $HOST\$" /etc/hosts || { sed -i '/^127.0.1.1/d' /etc/hosts; echo "127.0.1.1 $HOST" >> /etc/hosts; }
[ -d /etc/cloud/cloud.cfg.d ] && echo 'preserve_hostname: true' > /etc/cloud/cloud.cfg.d/99-hostname.cfg
# Sous-réseau local (auto-détecté)
IF=$(ip -4 route show default | awk '{print $5; exit}')
SUBNET=$(ip -4 route show dev "$IF" proto kernel scope link | awk '{print $1; exit}')
[ -n "$SUBNET" ] || { echo "Sous-réseau introuvable"; exit 1; }
# Fuseau
[ "$(timedatectl show -p Timezone --value)" = "$TZ_NAME" ] || timedatectl set-timezone "$TZ_NAME"
# Chrony
dpkg -s chrony >/dev/null 2>&1 || { apt-get update && apt-get install -y chrony; } || exit 1
{
  for S in $NTP_SERVERS; do echo "server $S"; done
  [ -n "$NTP_POOL" ] && echo "pool $NTP_POOL maxsources $POOL_MAX"
  cat <<EOF
driftfile /var/lib/chrony/chrony.drift
makestep 1 3
rtcsync
allow $SUBNET
logdir /var/log/chrony
log tracking measurements statistics
EOF
} > /tmp/chrony.new
cmp -s /tmp/chrony.new /etc/chrony/chrony.conf || { cp /tmp/chrony.new /etc/chrony/chrony.conf; systemctl restart chrony; }
systemctl enable chrony >/dev/null 2>&1
# tcpdump
dpkg -s tcpdump >/dev/null 2>&1 || { apt-get update && apt-get install -y tcpdump; } || exit 1
# Nombre de sources attendu (serveurs pool)
NB_SRC=$(echo $NTP_SERVERS | wc -w)
[ -n "$NTP_POOL" ] && NB_SRC=$((NB_SRC + POOL_MAX))
# Vérifications
echo "=== Hostname ===";        hostname
echo "=== Service chrony ===";  systemctl is-active chrony; systemctl is-enabled chrony
echo "=== Config ===";          grep -vE '^\s*(#|$)' /etc/chrony/chrony.conf
echo "=== iburst (vide = OK) ==="; grep iburst /etc/chrony/chrony.conf
echo "=== Fuseau ===";          timedatectl | grep -E "Time zone|synchronized"
echo "=== Écoute UDP 123 ===";  ss -ulpn | grep ':123'
echo "=== Sources (jusqu'à $NB_SRC attendues) ==="; chronyc sources
echo "=== Tracking (Stratum 2 à 4 attendu) ==="; chronyc tracking | grep -E "Reference ID|Stratum|System time|Leap status"
echo "=== Clients ===";         chronyc clients
echo "=== tcpdump ===";         tcpdump --version 2>&1 | head -1
true
