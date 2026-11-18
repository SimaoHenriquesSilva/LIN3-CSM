#!/bin/bash

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
allow 10.229.32.0/20
logdir /var/log/chrony
log tracking measurements statistics
EOF
cmp -s /tmp/chrony.new /etc/chrony/chrony.conf || { cp /tmp/chrony.new /etc/chrony/chrony.conf; systemctl restart chrony; }
systemctl enable chrony >/dev/null 2>&1

# Pare-feu (seulement si ufw est actif)
ufw status 2>/dev/null | grep -q "Status: active" && ufw allow from 10.229.32.0/20 to any port 123 proto udp
true
