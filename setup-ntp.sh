#!/bin/bash
IF=ens18

# Réseau : n'agit que si l'IP statique n'est pas en place
if ! ip -4 -o addr show dev $IF | grep -q "10.229.38.170/20"; then
  sed -i "/^\(auto\|allow-hotplug\) $IF\$/d;/^iface $IF inet/,/^[^[:space:]]/{/^iface $IF inet/d;/^[[:space:]]/d}" /etc/network/interfaces
  cat > /etc/network/interfaces.d/$IF <<EOF
auto $IF
iface $IF inet static
    address 10.229.38.170
    netmask 255.255.240.0
    gateway 10.229.32.1
    dns-nameservers 10.229.60.22 10.229.28.22
EOF
  systemctl is-active --quiet dhcpcd && systemctl disable --now dhcpcd
  systemctl restart networking
  ip -4 -o addr show dev $IF | awk '/dynamic/{print $4}' | xargs -r -I{} ip addr del {} dev $IF
fi

# Fuseau
[ "$(timedatectl show -p Timezone --value)" = Europe/Zurich ] || timedatectl set-timezone Europe/Zurich

# Chrony
dpkg -s chrony >/dev/null 2>&1 || { apt-get update && apt-get install -y chrony; }
cat > /tmp/chrony.new <<EOF
server ntp11.metas.ch
pool ch.pool.ntp.org maxsources 2
driftfile /var/lib/chrony/chrony.drift
makestep 1 3
rtcsync
allow 10.229.32.0/20
logdir /var/log/chrony
log tracking measurements statistics
EOF
cmp -s /tmp/chrony.new /etc/chrony/chrony.conf || { cp /tmp/chrony.new /etc/chrony/chrony.conf; systemctl restart chrony; }
systemctl enable chrony >/dev/null 2>&1

# Pare-feu (seulement si ufw est actif)
ufw status 2>/dev/null | grep -q "Status: active" && ufw allow from 10.229.32.0/20 to any port 123 proto udp
true