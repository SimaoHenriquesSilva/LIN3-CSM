#!/usr/bin/env bash
set -e

cat > /etc/chrony/chrony.conf <<'EOF'
# Fichier de configuration Chrony
server 10.0.3.10 prefer
server 10.0.3.11
driftfile /var/lib/chrony/chrony.drift
makestep 1 3
rtcsync
logdir /var/log/chrony
log tracking measurements statistics
EOF

systemctl restart chrony
chronyc sources
