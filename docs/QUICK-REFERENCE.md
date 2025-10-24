# N8N-R8 Quick Reference

## 🚀 Quick Start Commands

| Command | Description | Access |
|---------|-------------|---------|
| `make quick-start` | Basic N8N setup | http://localhost:5678 |
| `make quick-dev-full` | Development environment | N8N: :5678, PgAdmin: :8080 |
| `make quick-webhook-heavy` | High-traffic production | http://localhost |
| `make quick-full` | Enterprise with monitoring | Multiple services |

## 🔧 Essential Commands

### Basic Operations
```bash
make start              # Start N8N services
make stop               # Stop all services
make restart            # Restart services
make status             # Show service status
make health             # Check service health
make logs               # View all logs
```

### Development
```bash
make build-nodes        # Build custom nodes
make watch-nodes        # Watch mode for development
make start-development  # Dev environment
make logs-development   # Dev environment logs
```

### Production
```bash
make start-webhook-heavy    # High-traffic setup
make start-nginx           # With Nginx proxy
make start-traefik         # With Traefik proxy
make logs-webhook-heavy    # Webhook setup logs
```

### Maintenance
```bash
make backup             # Create backup
make restore            # List/restore backups
make update             # Update services
make clean              # Clean up resources
make reset              # Reset all data
```

### Monitoring
```bash
make monitor-full       # Start full monitoring
make monitor-basic      # Basic monitoring
make monitor-check      # Health check
make performance-baseline # Check performance
```

### Autoupdate
```bash
make autoupdate-enable  # Enable autoupdate
make autoupdate-status  # Show status
make autoupdate-check   # Check for updates
make autoupdate-update  # Manual update
```

## 📁 Directory Structure

```
n8n-r8/
├── .env                    # Main configuration
├── docker-compose.yml     # Basic setup
├── Makefile               # All commands
├── GETTING-STARTED.md     # Detailed setup guide
├── examples/              # Example configurations
│   ├── docker-compose/
│   │   ├── webhook-heavy/ # High-traffic setup
│   │   └── development/   # Dev environment
│   └── workflows/         # Sample workflows
├── nodes/                 # Custom nodes
├── scripts/               # Management scripts
├── monitoring/            # Monitoring configs
├── nginx/                 # Nginx configs
└── docs/                  # Documentation
```

## ⚙️ Configuration Files

| File | Purpose |
|------|---------|
| `.env` | Main environment variables |
| `docker-compose.yml` | Basic service configuration |
| `docker-compose.nginx.yml` | Nginx proxy setup |
| `docker-compose.traefik.yml` | Traefik proxy setup |
| `examples/*/docker-compose.yml` | Example configurations |

## 🌐 Default Access URLs

| Service | URL | Notes |
|---------|-----|-------|
| N8N (Basic) | http://localhost:5678 | Direct access |
| N8N (Nginx) | http://localhost | Via proxy |
| N8N (Dev) | http://localhost:5678 | Development mode |
| PgAdmin | http://localhost:8080 | Database admin |
| Traefik Dashboard | http://localhost:8080 | Proxy admin |
| Prometheus | http://localhost:9090 | Metrics |
| Grafana | http://localhost:3000 | Dashboards |

## 🔑 Key Environment Variables

```bash
# Database
POSTGRES_PASSWORD=your_secure_password

# N8N Authentication
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_password

# Security
N8N_ENCRYPTION_KEY=your_32_char_key
N8N_JWT_SECRET=your_jwt_secret

# Domain (Production)
N8N_HOST=your-domain.com
WEBHOOK_URL=https://your-domain.com/
```

## 🚨 Troubleshooting Quick Fixes

| Issue | Quick Fix |
|-------|-----------|
| Services won't start | `make check-env` |
| Port conflicts | Change ports in `.env` |
| Permission errors | `make setup` |
| Database issues | `make logs-postgres` |
| High memory usage | Reduce `NODE_OPTIONS` |
| Webhook timeouts | Use `make quick-webhook-heavy` |

## 📊 Performance Tuning

### Webhook-Heavy Setup
- **Rate Limits**: 100 req/s webhooks, 50 req/s API
- **Database**: 500 connections, parallel workers
- **Redis**: 1GB memory, LRU eviction
- **Nginx**: Advanced buffering and timeouts

### Development Setup
- **Debug Logging**: Full query logging
- **Hot Reload**: Automatic node compilation
- **Database Access**: Direct PostgreSQL access
- **Admin Tools**: PgAdmin interface

## 🔒 Security Checklist

- [ ] Change default passwords in `.env`
- [ ] Generate secure encryption keys
- [ ] Enable HTTPS in production
- [ ] Configure firewall rules
- [ ] Enable monitoring and alerts
- [ ] Set up regular backups
- [ ] Review security headers in nginx config

## 📋 Pre-flight Checklist

Before starting:
- [ ] Docker and Docker Compose installed
- [ ] `.env` file configured
- [ ] Required ports available (5678, 80, 443)
- [ ] Sufficient disk space (10GB+)
- [ ] Adequate RAM (2GB+ basic, 4GB+ webhook-heavy)

## 🆘 Emergency Commands

```bash
# Stop everything immediately
make stop-all

# Emergency cleanup
make clean-all

# Force reset (DANGER: loses all data)
make reset-force

# Check what's running
docker ps

# Emergency logs
docker logs n8n
```

## 📞 Getting Help

1. **Check logs**: `make logs`
2. **Verify config**: `make check-env`
3. **Review documentation**: `GETTING-STARTED.md`
4. **Check examples**: `examples/README.md`
5. **All commands**: `make help`
