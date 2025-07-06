# Browser-in-Container System

A scalable, secure browser-in-container system that provides isolated Chrome browser sessions accessible via VNC. Perfect for web automation, secure browsing, and multi-tenant applications.

## 🚀 Features

- **Isolated Browser Sessions**: Each session runs in its own container with persistent user profiles
- **VNC Web Access**: Browser accessible via web-based VNC client
- **Secure Authentication**: Token-based API authentication with domain restrictions
- **Session Management**: Auto-pause idle sessions, lifecycle management
- **Download Management**: File download tracking and retrieval
- **Navigation Controls**: Custom browser navigation (back, forward, refresh)
- **Kiosk Mode**: Full-screen browser without address bar
- **Right-Click Support**: Full mouse interaction including context menus
- **Keyboard Shortcuts**: Command+Arrow and Control+Arrow navigation

## 📋 System Requirements

- **Recommended**: 16 vCPU, 32GB RAM (supports ~40 concurrent sessions)
- **Minimum**: 4 vCPU, 8GB RAM (supports ~8 concurrent sessions)
- **Storage**: 100GB+ SSD for user profiles and downloads
- **OS**: Linux with Docker support

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   Frontend      │    │  Session Manager │    │  Browser Containers │
│   (portal2.ai)  │◄──►│     (API)        │◄──►│    (Chrome + VNC)   │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  User Profiles   │
                       │   (Persistent)   │
                       └──────────────────┘
```

## 🔧 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/RussellPetty/browser-container.git
cd browser-container
```

### 2. Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

Required environment variables:
```bash
AUTH_TOKEN=your-secure-token-here
PORT=3000
ALLOWED_DOMAIN=portal2.ai
NODE_ENV=production
```

### 3. Build and Run

```bash
# Build containers
docker compose build

# Start services
docker compose up -d

# Check status
docker compose ps
```

### 4. Test API

```bash
# Test with authentication
curl -X POST http://localhost:3000/session \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secure-token-here" \
  -d '{"url": "https://google.com", "email": "test@example.com"}'
```

## 🌐 Production Deployment

### Hetzner Cloud (Recommended)

**Server**: CPX51 (16 vCPU, 32GB RAM) - €60.49/month
**Capacity**: 40+ concurrent sessions (~€1.51 per session/month)

```bash
# 1. Provision Hetzner CPX51 server with Ubuntu 22.04
# 2. Install Docker and dependencies
curl -fsSL https://get.docker.com | sh
sudo apt install docker-compose-plugin nginx certbot -y

# 3. Clone and deploy
git clone https://github.com/RussellPetty/browser-container.git
cd browser-container

# 4. Configure environment
cp .env.example .env
# Edit .env with your settings

# 5. Deploy
docker compose -f docker-compose.prod.yml up -d
```

### SSL Certificate Setup

```bash
# Let's Encrypt
sudo certbot --nginx -d yourdomain.com

# Or use Cloudflare for DDoS protection
```

## 🔐 Security Features

### API Authentication
All endpoints require Bearer token authentication:
```bash
Authorization: Bearer <AUTH_TOKEN>
```

### Domain Restrictions
- iframe embedding restricted to `portal2.ai` only
- CORS policies enforce domain restrictions
- X-Frame-Options and CSP headers prevent unauthorized embedding

### Session Security
- Session validation before VNC access
- Automatic session cleanup and resource management
- Firewall rules block direct VNC port access

## 📡 API Endpoints

### Session Management
- `POST /session` - Create new browser session
- `POST /heartbeat/:sessionId` - Keep session alive
- `POST /stop/:sessionId` - Stop session

### Download Management
- `GET /session/:sessionId/downloads` - List downloads
- `GET /download/:sessionId/:filename` - Download file

### Browser Control
- `POST /browser-command/:sessionId` - Navigation commands (back, forward, refresh)

### Administration
- `GET /admin/users` - List all user profiles
- `GET /user/:userId` - Get user profile info

## 🎮 Frontend Integration

Example JavaScript integration:

```javascript
const AUTH_TOKEN = 'your-auth-token';

// Create session
const response = await fetch('https://api.yourdomain.com/session', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${AUTH_TOKEN}`
  },
  body: JSON.stringify({
    url: 'https://example.com',
    email: 'user@portal2.ai'
  })
});

const session = await response.json();

// Embed browser iframe
document.getElementById('browser').innerHTML = 
  `<iframe src="${session.iframeSrc}" width="100%" height="600"></iframe>`;
```

## 🔧 Configuration

### Session Lifecycle
- **Active**: Full resources, immediate response
- **Idle (5+ min)**: Reduced CPU priority
- **Paused (30+ min)**: Container paused, memory preserved
- **Cleanup (3+ days)**: Container removed, profile preserved

### Resource Limits
```yaml
# Per container limits
resources:
  limits:
    memory: 500MB
    cpus: 0.4
  reservations:
    memory: 350MB
    cpus: 0.2
```

### Browser Optimization
Chrome runs with optimized flags for performance:
- Memory pressure management
- Background process limitations
- Sync and extension disabling
- Kiosk mode for clean interface

## 📊 Monitoring

### Health Checks
```bash
# API health
curl -f https://api.yourdomain.com/admin/users \
  -H "Authorization: Bearer $AUTH_TOKEN"

# Container stats
docker stats

# Session count
docker ps | grep chrome | wc -l
```

### Log Files
- Session Manager: `docker compose logs session-manager`
- Browser Containers: `docker logs <container-id>`
- System: `/var/log/container-stats.log`

## 🛠️ Development

### Local Development Setup

```bash
# Install dependencies
cd session-manager && npm install

# Start development mode
npm run dev

# Run tests
./scripts/test-security.sh
```

### Adding Features

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open Pull Request

## 🔍 Troubleshooting

### Common Issues

**VNC Connection Reset**
- Check container logs: `docker logs <container-id>`
- Verify session is active: `GET /admin/users`
- Restart container: `docker restart <container-id>`

**Authentication Errors**
- Verify AUTH_TOKEN in environment
- Check API request headers
- Validate domain restrictions

**Performance Issues**
- Monitor resource usage: `docker stats`
- Check session count vs server capacity
- Review container lifecycle settings

### Debug Mode

```bash
# Enable debug logging
export DEBUG=browser-container:*

# Verbose container logs
docker compose logs -f --tail=100
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/RussellPetty/browser-container/issues)
- **Documentation**: [Wiki](https://github.com/RussellPetty/browser-container/wiki)
- **Security**: See [SECURITY.md](SECURITY.md)

## 🎯 Use Cases

- **Web Automation**: Selenium alternative with persistent sessions
- **Secure Browsing**: Isolated browser environments
- **Multi-tenant SaaS**: Browser-as-a-Service platform
- **Testing**: Cross-browser testing infrastructure
- **Education**: Safe browsing environments for students
- **Enterprise**: Secure access to web applications

---

**Cost-Effective Scaling**: Deploy on Hetzner for €1.51 per session/month - 60-70% cheaper than cloud alternatives!