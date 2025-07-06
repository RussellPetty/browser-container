# Deployment Guide

This guide covers deployment options for the Browser-in-Container system.

## 🚀 Quick Deployment (Hetzner Cloud)

### Prerequisites
- Hetzner Cloud account
- Domain name with DNS access
- SSH key pair

### 1. Provision Server

**Recommended**: CPX51 (16 vCPU, 32GB RAM) - €60.49/month

```bash
# Via Hetzner Cloud Console:
# 1. Create new server
# 2. Select CPX51
# 3. Choose Ubuntu 22.04 LTS
# 4. Add your SSH key
# 5. Note the server IP
```

### 2. Configure DNS

Set up A record pointing to your server:
```
api.yourdomain.com → YOUR_SERVER_IP
```

### 3. Deploy

```bash
# Clone repository
git clone https://github.com/RussellPetty/browser-container.git
cd browser-container

# Make deployment script executable
chmod +x deployment/deploy-hetzner.sh

# Deploy (replace with your values)
./deployment/deploy-hetzner.sh YOUR_SERVER_IP api.yourdomain.com
```

The script will:
- Install Docker and dependencies
- Upload codebase
- Configure environment
- Set up SSL certificate
- Configure firewall
- Start services

## 🔧 Manual Deployment

### Server Setup

```bash
# SSH into server
ssh root@YOUR_SERVER_IP

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
apt install docker-compose-plugin -y

# Install additional tools
apt install nginx certbot python3-certbot-nginx htop -y
```

### Application Setup

```bash
# Create app directory
mkdir -p /opt/browser-container
cd /opt/browser-container

# Clone repository
git clone https://github.com/RussellPetty/browser-container.git .

# Set up environment
cp .env.example .env
nano .env  # Edit with your settings
```

### SSL Certificate

```bash
# Option 1: Let's Encrypt (free)
certbot --nginx -d api.yourdomain.com

# Option 2: Upload custom certificate
mkdir -p deployment/ssl
# Upload cert.pem and key.pem to deployment/ssl/
```

### Start Services

```bash
# Build and start
docker compose build
docker compose -f deployment/docker-compose.prod.yml up -d

# Check status
docker compose ps
```

## 🌐 Cloud Platforms

### Railway (Easiest)

1. Connect GitHub repository
2. Set environment variables:
   ```
   AUTH_TOKEN=your-token
   ALLOWED_DOMAIN=portal2.ai
   NODE_ENV=production
   ```
3. Deploy automatically

**Cost**: $20-50/month for 10-20 sessions

### DigitalOcean App Platform

1. Create new app from GitHub
2. Configure build settings
3. Set environment variables
4. Deploy

**Cost**: $25-100/month for 20-40 sessions

### AWS ECS/Fargate

1. Create ECS cluster
2. Define task definitions
3. Set up load balancer
4. Configure auto-scaling

**Cost**: $75-200/month for 20-40 sessions

## 📊 Capacity Planning

### Session Limits by Server Size

| Server Type | vCPU | RAM | Sessions | Monthly Cost |
|-------------|------|-----|----------|--------------|
| CPX21 | 4 | 8GB | ~8 | €25.49 |
| CPX31 | 8 | 16GB | ~20 | €40.49 |
| CPX41 | 12 | 24GB | ~30 | €50.49 |
| CPX51 | 16 | 32GB | ~40 | €60.49 |
| CPX61 | 20 | 40GB | ~50 | €80.49 |

### Resource Requirements per Session
- **Memory**: 500-600MB
- **CPU**: 0.3-0.5 vCPU
- **Storage**: 300-500MB (profiles + downloads)

## 🔒 Security Configuration

### Firewall Rules

```bash
# Allow only necessary ports
ufw allow ssh
ufw allow 80
ufw allow 443

# Block direct VNC access
ufw deny 5900:5999

# Enable firewall
ufw enable
```

### SSL/TLS Configuration

```nginx
# Strong SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
ssl_prefer_server_ciphers off;
```

### Rate Limiting

```nginx
# API rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/m;
limit_req zone=api burst=20 nodelay;
```

## 📈 Monitoring

### Health Checks

```bash
# Run health check script
./deployment/health-check.sh api.yourdomain.com your-auth-token
```

### Log Monitoring

```bash
# Application logs
docker compose logs -f session-manager

# Browser container logs
docker logs chrome-SESSION_ID

# System logs
tail -f /var/log/syslog
```

### Resource Monitoring

```bash
# Container stats
docker stats

# System resources
htop

# Disk usage
df -h
du -sh /opt/browser-container/user-profiles
```

## 🔄 Auto-Scaling

### Horizontal Scaling (Multiple Servers)

1. Deploy to multiple servers
2. Set up load balancer (nginx/HAProxy)
3. Configure session affinity
4. Implement health checks

### Vertical Scaling (Larger Server)

1. Monitor resource usage
2. Upgrade server when reaching 80% capacity
3. Migrate using Docker volume backups

## 🚨 Troubleshooting

### Common Issues

**Container Fails to Start**
```bash
# Check logs
docker compose logs session-manager

# Check resources
docker stats
df -h
```

**SSL Certificate Issues**
```bash
# Renew certificate
certbot renew

# Check certificate
openssl x509 -in deployment/ssl/cert.pem -text -noout
```

**High Memory Usage**
```bash
# Check container limits
docker inspect CONTAINER_ID | grep -A 10 Resources

# Restart containers
docker compose restart
```

### Performance Optimization

**Container Limits**
```yaml
deploy:
  resources:
    limits:
      memory: 500M
      cpus: '0.4'
```

**Chrome Optimization**
```bash
# Already optimized flags in start.sh:
--memory-pressure-off
--max_old_space_size=256
--disable-background-networking
```

## 📋 Maintenance

### Regular Tasks

```bash
# Update system (monthly)
apt update && apt upgrade -y

# Clean up old containers (weekly)
docker system prune -f

# Backup user profiles (daily)
rsync -av /opt/browser-container/user-profiles/ /backup/

# Rotate logs (automated via logrotate)
```

### Backup Strategy

```bash
# User profiles backup
tar -czf backup-$(date +%Y%m%d).tar.gz user-profiles/

# Database/session backup
docker exec session-manager cat > sessions-backup.json

# Full system backup
rsync -av /opt/browser-container/ backup-server:/backups/
```

## 💰 Cost Optimization

### Tips for Lower Costs

1. **Use Hetzner instead of AWS/GCP** (60-70% savings)
2. **Implement session hibernation** (reduce active containers)
3. **Auto-cleanup old sessions** (save storage)
4. **Monitor usage patterns** (scale during peak hours)
5. **Use multiple smaller servers** instead of one large server

### Cost Comparison (40 sessions)

| Provider | Monthly Cost | Per Session |
|----------|-------------|-------------|
| Hetzner CPX51 | €60.49 | €1.51 |
| DigitalOcean | $120 | $3.00 |
| AWS ECS | $180 | $4.50 |
| Google Cloud | $160 | $4.00 |

**Hetzner provides the best value for dedicated resources!**