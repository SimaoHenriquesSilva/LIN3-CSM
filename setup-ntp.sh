#!/bin/bash
HOST=NTP-SRV-LIN

# Hostname (+ /etc/hosts, + cloud-init pour que ça survive au reboot)
[ "$(hostname)" = $HOST ] || hostnamectl set-hostname $HOST
grep -q "^127.0.1.1 $HOST\$" /etc/hosts || { sed -i '/^127.0.1.1/d' /etc/hosts; echo "127.0.1.1 $HOST" >> /etc/hosts; }
[ -d /etc/cloud/cloud.cfg.d ] && echo 'preserve_hostname: true' > /etc/cloud/cloud.cfg.d/99-hostname.cfg

# Sous-réseau local (auto-détecté)
IF=$(ip -4 route show default | awk '{print $5; exit}')
SUBNET=$(ip -4 route show dev "$IF" proto kernel scope link | awk '{print $1; exit}')
[ -n "$SUBNET" ] || { echo "Sous-réseau introuvable"; exit 1; }

# Fuseau
[ "$(timedatectl show -p Timezone --value)" = Europe/Zurich ] || timedatectl set-timezone Europe/Zurich

# Chrony
dpkg -s chrony >/dev/null 2>&1 || { apt-get update && apt-get install -y chrony; } || exit 1
cat > /tmp/chrony.new <<EOF
server ntp11.metas.ch
pool ch.pool.ntp.org maxsources 2
driftfile /var/lib/chrony/chrony.drift
makestep 1 3
rtcsync
allow $SUBNET
logdir /var/log/chrony
log tracking measurements statistics
EOF
cmp -s /tmp/chrony.new /etc/chrony/chrony.conf || { cp /tmp/chrony.new /etc/chrony/chrony.conf; systemctl restart chrony; }
systemctl enable chrony >/dev/null 2>&1

# tcpdump
dpkg -s tcpdump >/dev/null 2>&1 || { apt-get update && apt-get install -y tcpdump; } || exit 1

# Vérifications
echo "=== Hostname ===";        hostname
echo "=== Service chrony ===";  systemctl is-active chrony; systemctl is-enabled chrony
echo "=== Config ===";          grep -vE '^\s*(#|$)' /etc/chrony/chrony.conf
echo "=== iburst (vide = OK) ==="; grep iburst /etc/chrony/chrony.conf
echo "=== Fuseau ===";          timedatectl | grep -E "Time zone|synchronized"
echo "=== Écoute UDP 123 ===";  ss -ulpn | grep ':123'
echo "=== Sources ===";         chronyc sources
echo "=== Tracking ===";        chronyc tracking | grep -E "Reference ID|Stratum|System time|Leap status"
echo "=== Clients ===";         chronyc clients
echo "=== tcpdump ===";         tcpdump --version 2>&1 | head -1
true
