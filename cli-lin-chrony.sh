#!/usr/bin/env bash
set -e

# Mise à jour du système
apt update
apt upgrade -y

# Timezone
timedatectl set-timezone Europe/Zurich

# Configuration Chrony
cat > /etc/chrony/chrony.conf <<'EOF'
# Fichier de configuration Chrony
server 10.0.3.10 prefer iburst minpoll 5 maxpoll 5
server 10.0.3.11 iburst minpoll 5 maxpoll 5
driftfile /var/lib/chrony/chrony.drift
makestep 1 3
rtcsync
logdir /var/log/chrony
log tracking measurements statistics
EOF

systemctl restart chrony
chronyc sources
