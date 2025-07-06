#!/bin/bash

# Hetzner Cloud Deployment Script for Browser-in-Container System
# Usage: ./deploy-hetzner.sh <server-ip> <domain> [auth-token]

set -e

# Configuration
SERVER_IP="${1}"
DOMAIN="${2}"
AUTH_TOKEN="${3:-$(openssl rand -hex 32)}"
SSH_USER="root"
APP_DIR="/opt/browser-container"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validation
if [ -z "$SERVER_IP" ] || [ -z "$DOMAIN" ]; then
    log_error "Usage: $0 <server-ip> <domain> [auth-token]"
    log_error "Example: $0 1.2.3.4 api.yourdomain.com"
    exit 1
fi

log_info "🚀 Starting deployment to Hetzner Cloud"
log_info "Server: $SERVER_IP"
log_info "Domain: $DOMAIN"
log_info "Auth Token: ${AUTH_TOKEN:0:8}..."

# Test SSH connection
log_info "Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes $SSH_USER@$SERVER_IP echo "SSH connection successful" 2>/dev/null; then
    log_error "Cannot connect to server via SSH"
    log_error "Make sure your SSH key is added and server is accessible"
    exit 1
fi

# Upload codebase
log_info "📦 Uploading codebase..."
rsync -avz --progress \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude 'user-profiles' \
    --exclude '.env' \
    ./ $SSH_USER@$SERVER_IP:$APP_DIR/

# Deploy on server
log_info "🔧 Setting up server..."
ssh $SSH_USER@$SERVER_IP << EOF
set -e

# Update system
apt update && apt upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Install Docker Compose plugin
if ! docker compose version &> /dev/null; then
    apt install docker-compose-plugin -y
fi

# Install additional tools
apt install -y nginx certbot python3-certbot-nginx htop curl git

# Navigate to app directory
cd $APP_DIR

# Set up environment
cat > .env << EOL
AUTH_TOKEN=$AUTH_TOKEN
PORT=3000
ALLOWED_DOMAIN=$DOMAIN
NODE_ENV=production
EOL

chmod 600 .env

# Update Nginx config with domain
sed -i 's/your-domain.com/$DOMAIN/g' deployment/nginx.conf

# Create SSL directory
mkdir -p deployment/ssl

# Set up system limits
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# Configure Docker daemon
cat > /etc/docker/daemon.json << EOL
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "hard": 65536,
      "soft": 65536
    }
  }
}
EOL

systemctl restart docker

# Build and start services
docker compose build
docker compose -f deployment/docker-compose.prod.yml up -d

# Wait for services to start
sleep 15

# Health check
if curl -f http://localhost:3000/admin/users -H "Authorization: Bearer $AUTH_TOKEN" > /dev/null 2>&1; then
    echo "✅ Application health check passed"
else
    echo "❌ Application health check failed"
    docker compose -f deployment/docker-compose.prod.yml logs
    exit 1
fi

EOF

# Set up SSL certificate
log_info "🔒 Setting up SSL certificate..."
ssh $SSH_USER@$SERVER_IP << EOF
# Stop nginx if running
systemctl stop nginx || true

# Get SSL certificate
if certbot certonly --standalone -d $DOMAIN --agree-tos --register-unsafely-without-email --non-interactive; then
    # Copy certificates to deployment directory
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $APP_DIR/deployment/ssl/cert.pem
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $APP_DIR/deployment/ssl/key.pem
    
    # Set up auto-renewal
    echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
    
    echo "✅ SSL certificate obtained successfully"
else
    echo "❌ Failed to obtain SSL certificate"
    echo "You may need to configure DNS first or use manual certificate setup"
fi

# Start nginx with SSL
cd $APP_DIR
docker compose -f deployment/docker-compose.prod.yml restart nginx

EOF

# Set up firewall
log_info "🛡️ Configuring firewall..."
ssh $SSH_USER@$SERVER_IP << EOF
# Install and configure UFW
apt install -y ufw

# Reset UFW to defaults
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH, HTTP, HTTPS
ufw allow ssh
ufw allow 80
ufw allow 443

# Block direct VNC port access
ufw deny 5900:5999

# Enable firewall
ufw --force enable

# Install fail2ban
apt install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban

echo "✅ Firewall configured"
EOF

# Final health check
log_info "🔍 Performing final health check..."
sleep 10

if curl -f https://$DOMAIN/health > /dev/null 2>&1; then
    log_info "✅ HTTPS health check passed"
else
    log_warn "⚠️ HTTPS health check failed, checking HTTP..."
    if curl -f http://$DOMAIN/health > /dev/null 2>&1; then
        log_warn "HTTP works but HTTPS failed - check SSL certificate"
    else
        log_error "Both HTTP and HTTPS health checks failed"
    fi
fi

# Display summary
log_info "🎉 Deployment completed!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 DEPLOYMENT SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Domain: $DOMAIN"
echo "🔗 URL: https://$DOMAIN"
echo "🔑 Auth Token: $AUTH_TOKEN"
echo "🖥️  Server: $SERVER_IP"
echo "📊 Capacity: ~40 concurrent sessions"
echo "💰 Cost: €60.49/month (~€1.51 per session)"
echo ""
echo "📝 NEXT STEPS:"
echo "1. Update portal2.ai to use: https://$DOMAIN"
echo "2. Configure frontend with AUTH_TOKEN: $AUTH_TOKEN"
echo "3. Test session creation from portal2.ai"
echo "4. Monitor with: ssh $SSH_USER@$SERVER_IP 'docker stats'"
echo ""
echo "📞 SUPPORT:"
echo "- Logs: ssh $SSH_USER@$SERVER_IP 'cd $APP_DIR && docker compose logs'"
echo "- Status: curl -H \"Authorization: Bearer $AUTH_TOKEN\" https://$DOMAIN/admin/users"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"