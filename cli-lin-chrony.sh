#!/usr/bin/env bash
# Met à jour /etc/chrony/chrony.conf (sauvegarde, validation, redémarrage)
set -euo pipefail

CONF="/etc/chrony/chrony.conf"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être lancé avec sudo." >&2
    exit 1
fi

# Nouvelle configuration
cat > "$TMP" <<'EOF'
# Fichier de configuration Chrony
server 10.229.38.170 prefer
server 10.229.38.172
driftfile /var/lib/chrony/chrony.drift
makestep 1 3
rtcsync
logdir /var/log/chrony
log tracking measurements statistics
EOF

# Rien à faire si la config est déjà à jour
if [[ -f "$CONF" ]] && cmp -s "$TMP" "$CONF"; then
    echo "La configuration est déjà à jour, rien à faire."
    exit 0
fi

# Validation de la syntaxe avant de toucher à la config en place
if ! chronyd -p -f "$TMP" >/dev/null 2>&1; then
    echo "Configuration invalide, abandon." >&2
    exit 1
fi

# Sauvegarde de l'ancienne config
if [[ -f "$CONF" ]]; then
    BACKUP="${CONF}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p "$CONF" "$BACKUP"
    echo "Sauvegarde : $BACKUP"
fi

# Installation de la nouvelle config
install -m 644 -o root -g root "$TMP" "$CONF"

# Redémarrage et vérification
systemctl restart chrony
sleep 2
systemctl is-active --quiet chrony && echo "Service chrony actif."

echo "--- Sources ---"
chronyc sources -v
echo "--- Suivi ---"
chronyc tracking