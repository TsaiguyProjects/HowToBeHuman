#!/bin/bash
# Provision an OVHcloud VPS-2 (Ubuntu 24.04) for HowToBeHuman.
# Run ONCE on the fresh VPS as root (or with sudo):
#   curl -fsSL https://raw.githubusercontent.com/<org>/HowToBeHuman/main/vps/provision.sh | sudo bash
# Or: scp vps/provision.sh root@<VPS_IP>:/tmp/ && ssh root@<VPS_IP> 'bash /tmp/provision.sh'
#
# What it does: Docker + Compose plugin, UFW (22/80/443), fail2ban, /opt/how-to-be-human dir.
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/how-to-be-human}"
DEPLOY_USER="${DEPLOY_USER:-deploy}"

echo "==> Updating apt..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg ufw fail2ban git openssh-server

echo "==> Installing Docker (official repo)..."
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "==> Firewall (UFW): allow 22, 80, 443..."
ufw --force reset >/dev/null 2>&1 || true
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

echo "==> fail2ban for SSH..."
systemctl enable --now fail2ban

echo "==> App directory $APP_DIR ..."
mkdir -p "$APP_DIR"
if ! id "$DEPLOY_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$DEPLOY_USER"
  usermod -aG docker "$DEPLOY_USER"
  echo "Created user '$DEPLOY_USER' (add your SSH key: ssh-copy-id $DEPLOY_USER@<VPS_IP>)"
else
  usermod -aG docker "$DEPLOY_USER" || true
fi
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_DIR"

echo "==> Kernel niceties for containers..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
grep -q ip_forward /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

echo "✅ Provisioning complete."
echo "Next:"
echo "  1. Point DNS: A @ -> <VPS_IP>, A www -> <VPS_IP> (if used)"
echo "  2. ssh $DEPLOY_USER@<VPS_IP> 'git clone <repo-url> $APP_DIR && cd $APP_DIR && cp .env.example .env'"
echo "  3. Edit $APP_DIR/.env (SECRET_KEY, DOMAIN), then: docker compose -f docker-compose.prod.yml up -d --build"
