#!/usr/bin/env bash
# One-time setup of the Kiwix offline library on Linux Mint (or Ubuntu/Debian).
#   sudo ./install.sh
set -euo pipefail

INSTALL_DIR=/opt/kiwix
ZIM_DIR=/srv/kiwix/zim
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo ./install.sh" >&2; exit 1; }

# 1. Packages ----------------------------------------------------------------
log "Installing Docker and download tools"
apt-get update -q
apt-get install -y -q curl wget ca-certificates avahi-daemon
if ! command -v docker >/dev/null; then
  apt-get install -y -q docker.io
fi
if ! docker compose version >/dev/null 2>&1; then
  apt-get install -y -q docker-compose-v2 2>/dev/null \
    || apt-get install -y -q docker-compose-plugin 2>/dev/null \
    || { echo "Could not install 'docker compose'. Install Docker from docs.docker.com and re-run." >&2; exit 1; }
fi
systemctl enable --now docker

# Let the person who ran sudo use docker without sudo (takes effect at next login).
if [[ -n "${SUDO_USER:-}" ]]; then usermod -aG docker "$SUDO_USER"; fi

# 2. Files -------------------------------------------------------------------
log "Copying the kit to $INSTALL_DIR and creating $ZIM_DIR"
mkdir -p "$INSTALL_DIR" "$ZIM_DIR"
cp "$SRC_DIR"/{docker-compose.yml,update-zims.sh} "$INSTALL_DIR"/
# Keep an existing zims.conf so your edits survive a re-install.
[[ -f "$INSTALL_DIR/zims.conf" ]] || cp "$SRC_DIR/zims.conf" "$INSTALL_DIR"/
chmod +x "$INSTALL_DIR/update-zims.sh"

# 3. Content -----------------------------------------------------------------
log "Downloading content packs (this can take a while on the first run)"
"$INSTALL_DIR/update-zims.sh" || true

# 4. Server ------------------------------------------------------------------
log "Starting the Kiwix server"
(cd "$INSTALL_DIR" && docker compose pull -q && docker compose up -d)

# 5. Monthly auto-update -----------------------------------------------------
log "Installing a monthly update timer"
cp "$SRC_DIR"/kiwix-update.{service,timer} /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now kiwix-update.timer

# 6. Firewall (only if ufw is on) --------------------------------------------
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  log "Allowing port 8080 from the local network in ufw"
  for net in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12; do
    ufw allow from "$net" to any port 8080 proto tcp >/dev/null
  done
fi

# Done -----------------------------------------------------------------------
IP="$(hostname -I | awk '{print $1}')"
cat <<EOF

  Kiwix is running.
    On this network:   http://$IP:8080
    Or by name:        http://$(hostname).local:8080
    Content folder:    $ZIM_DIR
    Edit packs:        sudo nano $INSTALL_DIR/zims.conf  then  sudo $INSTALL_DIR/update-zims.sh

EOF