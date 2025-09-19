# N8N-R8: Production-Ready N8N Deployment

A comprehensive, production-ready N8N deployment solution with Docker Compose, featuring multiple proxy options, monitoring, security, custom nodes, and automation capabilities.

## 🚀 Quick Start

Choose your setup:

```bash
# Basic setup (recommended for beginners)
make quick-start

# Development environment with debugging tools
make quick-dev-full

# High-traffic production setup (100+ webhooks/s)
make quick-webhook-heavy

# Enterprise setup with monitoring and security
make quick-full
```

**📖 New to N8N-R8?** Start with our [**Getting Started Guide**](GETTING-STARTED.md) | **⚡ Need quick commands?** Check the [**Quick Reference**](QUICK-REFERENCE.md) | **📊 Project status?** Run `make dashboard`
- [⚡ Quick Start](#-quick-start)
- [📁 Project Structure](#-project-structure)
- [🛠️ Prerequisites](#️-prerequisites)
- [🔧 Configuration](#-configuration)
- [📊 Monitoring](#-monitoring)
- [🔄 Autoupdate System](#-autoupdate-system)
- [🔧 Troubleshooting](#-troubleshooting)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [🆘 Support](#-support)

## 🚀 Features

- **Production-ready N8N setup** with PostgreSQL and Redis
- **Multiple proxy options**: Nginx or Traefik reverse proxy
- **SSL/TLS support** with automatic certificate management
- **Health checks** for all services
- **Comprehensive monitoring** with Prometheus, Grafana, and alerting
- **Backup and restore** functionality
- **Reset and cleanup** scripts
- **Proper security** configurations
- **Log management** with rotation and retention
- **Comprehensive autoupdate system** with Watchtower and scheduled updates
- **Easy deployment** with one-command startup

## ⚡ Quick Start

**Start N8N with one command:**
```bash
make start-nginx    # Start with Nginx proxy (recommended)
```

**Success Indicators:**
- ✅ Check logs with `make logs` - expect 'n8n ready on 0.0.0.0 port 5678'
- ✅ All containers healthy: `make health`
- ✅ Access N8N at http://localhost

**Access N8N:**
- Open http://localhost in your browser
- Login with your credentials (default: admin/changeme123!)

<!-- Screenshot placeholder: Add screenshot of n8n UI post-startup -->
![N8N Dashboard](docs/images/n8n-dashboard-screenshot.png)
*N8N Dashboard after successful startup*

**Stop when done:**
```bash
make stop
```

## 📁 Project Structure

```
n8n-r8/
├── [docker-compose.yml](docker-compose.yml)              # Main N8N services
├── [docker-compose.nginx.yml](docker-compose.nginx.yml)        # Nginx proxy override
├── [docker-compose.traefik.yml](docker-compose.traefik.yml)      # Traefik proxy override
├── [.env](.env)                            # Environment variables
├── data/                           # Persistent data
│   ├── n8n/                       # N8N workflows and settings
│   ├── postgres/                  # PostgreSQL database
│   ├── redis/                     # Redis cache and queue data
│   └── traefik/                   # Traefik ACME certificates
├── nginx/                          # Nginx configuration
│   ├── nginx.conf                 # Main Nginx config
│   ├── conf.d/                    # Site configurations
│   ├── ssl/                       # SSL certificates
│   └── html/                      # Static files
├── traefik/                        # Traefik configuration
│   ├── traefik.yml               # Main Traefik config
│   ├── dynamic/                   # Dynamic configuration
│   └── logs/                      # Traefik logs
├── backups/                        # Backup storage
├── scripts/                        # Utility scripts
│   ├── backup.sh                  # Backup script
│   ├── restore.sh                 # Restore script
│   ├── reset.sh                   # Reset script
│   ├── start-nginx.sh             # Start with Nginx
│   ├── start-traefik.sh           # Start with Traefik
│   └── start-monitoring.sh        # Start monitoring
├── monitoring/                     # Monitoring system
│   ├── scripts/                   # Monitoring scripts
│   ├── config/                    # Monitoring configuration
│   ├── logs/                      # Monitoring logs
│   └── data/                      # Monitoring data
├── nodes/                          # Custom N8N nodes development
│   ├── src/                       # Node source code
│   ├── dist/                      # Compiled nodes
│   ├── templates/                 # Node templates
│   ├── tests/                     # Node tests
│   ├── scripts/                   # Build scripts
│   └── package.json               # Node dependencies
├── systemd/                        # Systemd service files
│   ├── n8n-local.service         # Basic service
│   ├── n8n-nginx.service         # Nginx service
│   ├── n8n-traefik.service       # Traefik service
│   └── README.md                  # Systemd documentation
├── docker-compose.monitoring.yml   # Monitoring services
├── docker-compose.custom-nodes.yml # Custom nodes development
├── [README.md](README.md)
├── [.gitignore](.gitignore)
└── [Makefile](Makefile)                       # Common commands
```

## 🛠️ Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 4GB+ RAM recommended
- 10GB+ disk space

## ⚡ Quick Start

### 1. Clone and Setup

```bash
# Navigate to your projects directory
cd /home/ram/projects

# The directory structure is already created as n8n-r8/
cd n8n-r8

# Make scripts executable
chmod +x scripts/*.sh
```

### 2. Configure Environment

Edit the `.env` file to customize your setup:

```bash
# Essential settings to change:
N8N_BASIC_AUTH_USER=your_username
N8N_BASIC_AUTH_PASSWORD=your_secure_password
POSTGRES_PASSWORD=your_postgres_password
REDIS_PASSWORD=your_redis_password
N8N_ENCRYPTION_KEY=your-32-character-encryption-key
N8N_JWT_SECRET=your-jwt-secret-key
```

### 3. Choose Your Setup

#### Option A: Direct Access (Development)
```bash
# Using script (recommended)
./scripts/start-direct.sh -d

# Or using make
make start-direct
```
Access N8N at: http://localhost:5678

#### Option B: Basic N8N (No Proxy)
```bash
docker compose up -d
```
Access N8N at: http://localhost:5678

#### Option C: With Nginx Proxy
```bash
./scripts/start-nginx.sh -d
```
Access N8N at: http://localhost

#### Option D: With Traefik Proxy
```bash
./scripts/start-traefik.sh -d
```
Access N8N at: http://localhost
Traefik Dashboard: http://localhost:8080

#### Option E: With Monitoring
```bash
# Basic monitoring (recommended for development)
make monitor-basic

# Full monitoring stack (recommended for production)
make monitor-full
```
Monitoring interfaces:
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)
- Alertmanager: http://localhost:9093

#### Stop All Services
```bash
# Stop all services regardless of configuration
./scripts/stop-all.sh

# Or using make
make stop-all
```

#### Custom Nodes Development
```bash
# Start development environment (with watch mode)
./scripts/start-custom-nodes.sh dev -d

# Build nodes and start N8N
./scripts/start-custom-nodes.sh build -d

# Start with proxy
./scripts/start-custom-nodes.sh build --proxy nginx -d

# Build nodes only
cd nodes && ./scripts/build.sh build
```

## 🔧 Configuration

### Environment Variables

> ⚠️ **Production Security Warning**: Never commit `.env` files to git! Always use secure, unique passwords and keys in production.

Key environment variables in `.env`:

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_BASIC_AUTH_USER` | admin | N8N admin username |
| `N8N_BASIC_AUTH_PASSWORD` | changeme123! | N8N admin password |
| `N8N_HOST` | localhost | Domain name for N8N |
| `POSTGRES_PASSWORD` | n8n_secure_password_123! | PostgreSQL password |
| `REDIS_PASSWORD` | redis_secure_password_123! | Redis password |
| `N8N_ENCRYPTION_KEY` | Required | N8N encryption key (32 chars) |
| `N8N_JWT_SECRET` | Required | JWT secret key |

### SSL/HTTPS Setup

#### For Nginx:
1. Place SSL certificates in `nginx/ssl/`:
   - `cert.pem` - Certificate file
   - `key.pem` - Private key file
2. Uncomment HTTPS server block in `nginx/conf.d/n8n.conf`
3. Restart services

#### For Traefik:
1. Update `SSL_EMAIL` in `.env`
2. For production: `./scripts/start-traefik.sh -d`
3. For testing: `./scripts/start-traefik.sh --staging -d`

## 📊 Monitoring

### Quick Start Monitoring

```bash
# Basic monitoring (script-based)
make monitor-basic

# Full monitoring stack (Prometheus, Grafana, etc.)
make monitor-full

# Minimal monitoring (lightweight)
make monitor-minimal

# One-time health check
make monitor-check

# Check disk usage
make monitor-disk
```

### Monitoring Features

#### 🔍 **Health Monitoring**
- Service availability checks (N8N, PostgreSQL, Redis, proxies)
- HTTP endpoint monitoring
- Container health status
- System resource monitoring (CPU, Memory, Disk)

#### 📈 **Metrics Collection**
- Prometheus metrics collection
- Grafana dashboards for visualization
- Custom business metrics
- Historical data retention

#### 🚨 **Alerting System**
- Email notifications for critical issues
- Slack/Discord/PagerDuty integration
- Configurable alert thresholds
- Alert escalation and cooldown

#### 💾 **Log Management**
- Centralized log collection with Loki
- Automatic log rotation
- Configurable retention periods
- Log analysis and search

### Monitoring Interfaces

- **Prometheus**: http://localhost:9090 - Metrics collection and queries
- **Grafana**: http://localhost:3000 - Dashboards and visualization
  - **Default Login**: `admin` / `admin` (change on first login)
  - **Sample Query**: `n8n_executions_total` - Total workflow executions
  - **Queue Length Query**: `n8n_queue_waiting_total` - Workflows waiting in queue
- **Alertmanager**: http://localhost:9093 - Alert management
- **Uptime Kuma**: http://localhost:3001 - Uptime monitoring
  - **Default Login**: `admin` / `prom-operator`

### Configuration

Edit `monitoring/config/monitor.conf` for basic settings:

```bash
# Check interval and thresholds
CHECK_INTERVAL=30
DISK_THRESHOLD=85
MEMORY_THRESHOLD=90

# Email alerts
ENABLE_EMAIL_ALERTS=true
EMAIL_TO="admin@example.com"
```

For detailed monitoring setup, see [monitoring/README.md](monitoring/README.md).

## 🔄 Management Commands

### Using Scripts

#### Startup Scripts
```bash
# Direct access (development)
./scripts/start-direct.sh -d                    # Start on port 5678
./scripts/start-direct.sh --port 8080 -d        # Custom port

# Proxy configurations
./scripts/start-nginx.sh -d                     # Start with Nginx proxy
./scripts/start-traefik.sh -d                   # Start with Traefik proxy
./scripts/start-traefik.sh --staging -d         # Traefik with staging SSL

# Monitoring
./scripts/start-monitoring.sh basic -d          # Basic monitoring
./scripts/start-monitoring.sh full -d           # Full monitoring stack

# Stop all services
./scripts/stop-all.sh                           # Interactive stop
./scripts/stop-all.sh -f                        # Force stop
./scripts/stop-all.sh -f -v                     # Force stop + remove volumes
```

#### Management Scripts
```bash
# Create backup
./scripts/backup.sh

# List available backups
./scripts/restore.sh --list

# Restore from backup
./scripts/restore.sh n8n_backup_20240101_120000

# Reset everything (with confirmation)
./scripts/reset.sh --full

# Reset with backup first
./scripts/reset.sh --backup --full
```

### Using Docker Compose

```bash
# Basic startup
docker compose up -d

# With Nginx
docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d

# With Traefik
docker compose -f docker-compose.yml -f docker-compose.traefik.yml up -d

# View logs
docker compose logs -f

# Stop services
docker compose down

# Update and restart
docker compose pull && docker compose up -d
```

### Using Makefile

```bash
# Start basic setup
make start

# Start with Nginx
make start-nginx

# Start with Traefik  
make start-traefik

# Stop all services
make stop

# View logs
make logs

# Create backup
make backup

# Reset everything
make reset
```

## 📊 Monitoring and Logs

### Service Health

Check service health:
```bash
docker compose ps
```

### Logs

View logs for all services:
```bash
docker compose logs -f
```

View logs for specific service:
```bash
docker compose logs -f n8n
docker compose logs -f postgres
docker compose logs -f redis
```

### Nginx Logs
```bash
# Access logs
tail -f /var/log/nginx/access.log

# Error logs  
tail -f /var/log/nginx/error.log
```

### Traefik Logs
```bash
# Traefik container logs
docker logs n8n-traefik -f

# Traefik log files
tail -f traefik/logs/traefik.log
tail -f traefik/logs/access.log
```

## 🔒 Security

### Default Security Features

- Basic authentication enabled by default
- Rate limiting configured
- Security headers set
- Internal network isolation
- Health checks for all services
- Secure SSL/TLS configuration

### Security Checklist

- [ ] Change default passwords in `.env`
- [ ] Generate secure encryption keys
- [ ] Configure SSL certificates
- [ ] Set up firewall rules
- [ ] Enable log monitoring
- [ ] Regular backup schedule
- [ ] Update Docker images regularly

## 💾 Backup and Restore

### Automatic Backups

The backup script creates comprehensive backups including:
- N8N workflows and credentials
- PostgreSQL database dump
- Redis data
- Configuration files

### Manual Backup
```bash
./scripts/backup.sh
```

### Restore Options
```bash
# List backups
./scripts/restore.sh --list

# Full restore
./scripts/restore.sh n8n_backup_20240101_120000

# Data only
./scripts/restore.sh --data-only n8n_backup_20240101_120000

# Database only
./scripts/restore.sh --db-only n8n_backup_20240101_120000
```

## 🔧 Troubleshooting

### 📜 Logs First Approach

When troubleshooting issues, always start by checking the logs:

```bash
# Check all service logs
make logs

# Check specific service logs
docker compose logs -f n8n        # N8N service
docker compose logs -f postgres   # PostgreSQL database
docker compose logs -f redis      # Redis cache
docker compose logs -f nginx      # Nginx proxy (if running)
docker compose logs -f traefik    # Traefik proxy (if running)
```

### Common Issues

#### Services won't start
```bash
# Check Docker daemon
sudo systemctl status docker

# Check logs
docker compose logs

# Reset and try again
./scripts/reset.sh --containers-only
docker compose up -d
```

#### Permission issues
```bash
# Fix data directory permissions
sudo chown -R 1000:1000 data/
chmod -R 755 data/
```

#### Database connection issues
```bash
# Check PostgreSQL logs
docker compose logs postgres

# Reset database
./scripts/reset.sh --data-only
docker compose up -d
```

#### SSL certificate issues (Traefik)
```bash
# Check Traefik logs
docker logs n8n-traefik

# Use staging environment first
./scripts/start-traefik.sh --staging -d

# Check ACME file permissions
ls -la data/traefik/acme/acme.json
```

### Performance Tuning

#### For high-load environments:

1. **Increase PostgreSQL resources**:
   ```yaml
   # In docker-compose.yml, postgres service
   deploy:
     resources:
       limits:
         memory: 2G
       reservations:
         memory: 1G
   ```

2. **Increase Redis memory**:
   ```bash
   # In docker-compose.yml, redis command
   --maxmemory 512mb
   ```

3. **Scale N8N workers**:
   ```bash
   docker compose up -d --scale n8n=3
   ```

### ⚠️ Known Limitations

- **Multi-architecture support**: Currently optimized for x86_64 architecture
- **Windows compatibility**: Some scripts may require WSL2 for full functionality
- **Resource requirements**: Minimum 4GB RAM recommended for full stack
- **SSL certificates**: Automatic renewal requires proper DNS configuration
- **Custom nodes**: Hot-reloading requires manual container restart
- **Backup size**: Large workflow histories may result in substantial backup files

## 🚀 Production Deployment

### Pre-deployment Checklist

- [ ] Update all passwords and secrets
- [ ] Configure proper domain names
- [ ] Set up SSL certificates
- [ ] Configure firewall rules
- [ ] Set up monitoring
- [ ] Configure backup schedule
- [ ] Test restore procedures

### Production Environment Variables

```bash
# Production settings
NODE_ENV=production
N8N_SECURE_COOKIE=true
N8N_PROTOCOL=https
TRAEFIK_API_INSECURE=false
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. **Code Style**: Use Prettier for JavaScript formatting (see [nodes/.prettierrc](nodes/.prettierrc))
5. Test thoroughly
6. Submit a pull request

### Development Guidelines

- Follow the existing code style and conventions
- Add tests for new features
- Update documentation for any changes
- Ensure all services start successfully after changes

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Documentation**: Check this README and inline comments
- **Issues**: Create an issue in the repository
- **N8N Documentation**: https://docs.n8n.io/
- **Docker Documentation**: https://docs.docker.com/

## 🔄 Updates

To update N8N and other services:

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# Or use the script
./scripts/start-nginx.sh --build -d
```

## 🔄 Autoupdate System

N8N-R8 includes a comprehensive autoupdate system with multiple update methods and safety features:

### Quick Start Autoupdate

```bash
# Enable autoupdate with Watchtower (recommended)
make autoupdate-enable
make start-with-autoupdate

# Check autoupdate status
make autoupdate-status
```

### Update Methods

#### 1. Watchtower Method (Real-time)
```bash
# Start with automatic updates
make start-with-autoupdate

# Or enable Watchtower separately
make autoupdate-watchtower
```

#### 2. Scheduled Updates (Cron-based)
```bash
# Install scheduled updates (runs daily at 2 AM)
make autoupdate-schedule

# Check for updates manually
make autoupdate-check
```

#### 3. Manual Updates
```bash
# Perform manual update with backup
make autoupdate-update

# Disable autoupdate
make autoupdate-disable
```

### Safety Features

- ✅ **Pre-update backup creation**
- ✅ **Health checks after updates**
- ✅ **Automatic rollback on failure**
- ✅ **Comprehensive logging**
- ✅ **Slack and email notifications**
- ✅ **Configurable update schedules**

### Configuration

Configure autoupdate settings in `.env.autoupdate`:

```bash
# Copy example configuration
cp .env.autoupdate.example .env.autoupdate

# Edit settings
vim .env.autoupdate
```

For detailed autoupdate documentation, see [docs/autoupdate.md](docs/autoupdate.md).

## 🔄 Auto-Start Options

### Option 1: Manual Start (Simplest)
```bash
make start-nginx    # Start N8N with Nginx
```

### Option 2: Systemd Service (Auto-start on boot)
```bash
# Install and enable auto-start
make systemd-install-nginx
sudo systemctl enable n8n-nginx.service

# Manual control
sudo systemctl start n8n-nginx.service    # Start
sudo systemctl stop n8n-nginx.service     # Stop
sudo systemctl status n8n-nginx.service   # Check status
```

### Option 3: Desktop Shortcut
- Double-click the **N8N-R8** icon on your desktop
- Terminal will open and start N8N automatically

### Option 4: Terminal Aliases
After restarting your terminal, use these shortcuts:
```bash
n8n-start     # Start N8N
n8n-stop      # Stop N8N
n8n-status    # Check status
n8n-logs      # View logs
n8n-health    # Health check
n8n-restart   # Restart services
```

## 📄 License

### N8N-R8 Project License

This N8N-R8 project (Docker setup, scripts, and configurations) is released under the **MIT License**.

```
MIT License

Copyright (c) 2024 N8N-R8 Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### N8N License Information

> 📊 **N8N Community vs Enterprise**
> 
> This project uses **N8N Community Edition** by default, which is free for most use cases under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md). 
> 
> **N8N Enterprise** features (LDAP/SSO, advanced logging, priority support) require a commercial license.

**N8N** itself is subject to its own licensing terms:

- **N8N Community Edition**: Available under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md)
- **N8N Cloud/Enterprise**: Requires a commercial license for advanced features

#### N8N License Configuration

To use N8N with a license key (for Cloud/Enterprise features):

1. **Add your license key** to the `.env` file:
   ```bash
   N8N_LICENSE_ACTIVATION_KEY=your-license-key-here
   ```

2. **Restart the services** to apply the license:
   ```bash
   make restart
   ```

3. **Verify license activation** in the N8N web interface under Settings → License

#### N8N Community vs Licensed Features

| Feature | Community | Licensed |
|---------|-----------|----------|
| Workflow Automation | ✅ | ✅ |
| Basic Nodes | ✅ | ✅ |
| Database Integration | ✅ | ✅ |
| API Access | ✅ | ✅ |
| Advanced Logging | ❌ | ✅ |
| LDAP/SSO Authentication | ❌ | ✅ |
| Advanced Permissions | ❌ | ✅ |
| Priority Support | ❌ | ✅ |
| Advanced Monitoring | ❌ | ✅ |

### Third-Party Components

This project includes several third-party components, each with their own licenses:

- **Docker**: [Apache License 2.0](https://github.com/docker/docker/blob/master/LICENSE)
- **PostgreSQL**: [PostgreSQL License](https://www.postgresql.org/about/licence/)
- **Redis**: [BSD 3-Clause License](https://redis.io/docs/about/license/)
- **Nginx**: [2-clause BSD License](http://nginx.org/LICENSE)
- **Traefik**: [MIT License](https://github.com/traefik/traefik/blob/master/LICENSE.md)
- **Prometheus**: [Apache License 2.0](https://github.com/prometheus/prometheus/blob/main/LICENSE)
- **Grafana**: [AGPL v3.0](https://github.com/grafana/grafana/blob/main/LICENSE)

### Custom Nodes License

Custom nodes developed within this project are subject to the same MIT License as the main project, unless otherwise specified in individual node files.

### Contributing

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

### Disclaimer

This project is not officially affiliated with n8n GmbH. N8N is a trademark of n8n GmbH. Please refer to the official [N8N documentation](https://docs.n8n.io/) for the most up-to-date licensing information.

---

**Happy Automating with N8N! 🎉**

## 💬 Questions & Support

**Questions?** [Open an issue!](https://github.com/your-username/n8n-r8/issues/new)

**Found this helpful?** ⭐ Star the repository and share with others!

**Need help?** Join the discussion in [Issues](https://github.com/your-username/n8n-r8/issues) or check the [N8N Community](https://community.n8n.io/)
