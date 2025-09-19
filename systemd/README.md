# N8N-R8 Systemd Services

This directory contains systemd service files for automatically starting N8N-R8 on system boot. The services provide different configurations for various deployment scenarios.

## 🚀 Available Services

### 1. **n8n-local.service** (Basic)
- Basic N8N setup with PostgreSQL and Redis
- No reverse proxy
- Direct access on port 5678
- Minimal resource usage

### 2. **n8n-nginx.service** (Nginx Proxy)
- N8N with Nginx reverse proxy
- HTTP access on port 80
- SSL support (when configured)
- Load balancing and caching

### 3. **n8n-traefik.service** (Traefik Proxy)
- N8N with Traefik reverse proxy
- Automatic SSL certificates via Let's Encrypt
- HTTP/HTTPS access on ports 80/443
- Dashboard on port 8080

### 4. **n8n-monitoring.service** (Full Stack)
- N8N with complete monitoring stack
- Prometheus, Grafana, Alertmanager
- Resource monitoring and alerting
- Higher resource requirements

## ⚡ Quick Start

### Using the Installation Script (Recommended)

```bash
# Make the script executable
chmod +x scripts/install-systemd.sh

# List available services
sudo ./scripts/install-systemd.sh list

# Install basic N8N service
sudo ./scripts/install-systemd.sh install basic

# Enable and start the service
sudo ./scripts/install-systemd.sh enable basic
sudo ./scripts/install-systemd.sh start basic

# Check service status
sudo ./scripts/install-systemd.sh status basic
```

### Manual Installation

```bash
# 1. Copy service file
sudo cp systemd/n8n-local.service /etc/systemd/system/

# 2. Edit the service file (update paths and user)
sudo nano /etc/systemd/system/n8n-local.service

# 3. Reload systemd
sudo systemctl daemon-reload

# 4. Enable and start service
sudo systemctl enable n8n-local.service
sudo systemctl start n8n-local.service

# 5. Check status
sudo systemctl status n8n-local.service
```

## 🔧 Configuration

### Required Customization

Before installing any service, you **must** customize these settings:

1. **User and Group**: Update `User=` and `Group=` to your username
2. **Working Directory**: Update `WorkingDirectory=` to your project path
3. **Environment File**: Update `EnvironmentFile=` paths

### Example Customization

```ini
# Change from:
User=ram
Group=ram
WorkingDirectory=/home/ram/projects/n8n-r8
EnvironmentFile=/home/ram/projects/n8n-r8/.env

# To your setup:
User=yourusername
Group=yourusername
WorkingDirectory=/path/to/your/n8n-r8
EnvironmentFile=/path/to/your/n8n-r8/.env
```

### Service Options

Each service file has multiple `ExecStart` options commented out. Choose the one that matches your desired configuration:

```ini
# Basic N8N (default)
ExecStart=/usr/bin/docker compose -f docker-compose.yml up -d

# With Nginx proxy
# ExecStart=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d

# With Traefik proxy
# ExecStart=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.traefik.yml up -d
```

## 📋 Management Commands

### Using the Installation Script

```bash
# Service management
sudo ./scripts/install-systemd.sh install basic     # Install service
sudo ./scripts/install-systemd.sh uninstall basic   # Remove service
sudo ./scripts/install-systemd.sh enable basic      # Enable auto-start
sudo ./scripts/install-systemd.sh disable basic     # Disable auto-start
sudo ./scripts/install-systemd.sh start basic       # Start service
sudo ./scripts/install-systemd.sh stop basic        # Stop service
sudo ./scripts/install-systemd.sh restart basic     # Restart service
sudo ./scripts/install-systemd.sh status basic      # Show status

# View logs
sudo ./scripts/install-systemd.sh logs basic        # Show logs
sudo ./scripts/install-systemd.sh logs basic -f     # Follow logs
sudo ./scripts/install-systemd.sh logs basic -n 50  # Last 50 lines

# Multiple services
sudo ./scripts/install-systemd.sh install all       # Install all services
sudo ./scripts/install-systemd.sh start "basic nginx"  # Start multiple
```

### Using Systemctl Directly

```bash
# Service control
sudo systemctl start n8n-local.service      # Start service
sudo systemctl stop n8n-local.service       # Stop service
sudo systemctl restart n8n-local.service    # Restart service
sudo systemctl reload n8n-local.service     # Reload configuration

# Boot management
sudo systemctl enable n8n-local.service     # Enable auto-start
sudo systemctl disable n8n-local.service    # Disable auto-start

# Status and logs
sudo systemctl status n8n-local.service     # Show status
sudo journalctl -u n8n-local.service -f     # Follow logs
sudo journalctl -u n8n-local.service -n 100 # Last 100 lines
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Service Fails to Start

```bash
# Check service status
sudo systemctl status n8n-local.service

# View detailed logs
sudo journalctl -u n8n-local.service -n 50

# Common causes:
# - Docker not running: sudo systemctl start docker
# - Wrong user/path in service file
# - Missing .env file
# - Port conflicts
```

#### 2. Permission Issues

```bash
# Check file permissions
ls -la /etc/systemd/system/n8n-local.service

# Fix permissions if needed
sudo chmod 644 /etc/systemd/system/n8n-local.service
sudo chown root:root /etc/systemd/system/n8n-local.service

# Reload systemd
sudo systemctl daemon-reload
```

#### 3. Docker Issues

```bash
# Ensure Docker is running
sudo systemctl status docker
sudo systemctl start docker

# Check Docker Compose files
docker compose -f docker-compose.yml config

# Test manual startup
cd /path/to/n8n-r8
docker compose up -d
```

#### 4. Environment Issues

```bash
# Check .env file exists and is readable
ls -la .env
cat .env

# Verify environment variables
sudo systemctl show n8n-local.service --property=Environment
```

### Service States

| State | Description | Action |
|-------|-------------|--------|
| `active (running)` | Service is running normally | ✅ Good |
| `inactive (dead)` | Service is stopped | Start with `systemctl start` |
| `failed` | Service failed to start | Check logs with `journalctl` |
| `activating` | Service is starting | Wait or check logs if stuck |

### Log Analysis

```bash
# Show service logs with timestamps
sudo journalctl -u n8n-local.service --since "1 hour ago"

# Show only errors
sudo journalctl -u n8n-local.service -p err

# Show logs from specific boot
sudo journalctl -u n8n-local.service -b

# Export logs to file
sudo journalctl -u n8n-local.service > n8n-service.log
```

## 🔒 Security Considerations

### Service Security Features

All service files include security hardening:

```ini
# Security settings
NoNewPrivileges=true    # Prevent privilege escalation
PrivateTmp=true        # Isolated /tmp directory
```

### Additional Security

1. **Run as non-root user**: Services run as specified user, not root
2. **Resource limits**: Optional memory and CPU limits
3. **Network isolation**: Docker network isolation
4. **File permissions**: Proper file and directory permissions

### Recommended Security Enhancements

```ini
# Add to service file for enhanced security
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/path/to/n8n-r8/data
```

## 📊 Monitoring Service Health

### Built-in Health Checks

Services include health checks that verify:
- Docker containers are running
- HTTP endpoints are responding
- Required ports are accessible

### Monitoring Integration

For production deployments, consider:

1. **System monitoring**: Use the monitoring service template
2. **Log aggregation**: Forward systemd logs to centralized logging
3. **Alerting**: Set up alerts for service failures

```bash
# Monitor service with systemd
sudo systemctl is-active n8n-local.service
sudo systemctl is-enabled n8n-local.service
sudo systemctl is-failed n8n-local.service
```

## 🔄 Updates and Maintenance

### Updating Services

```bash
# Stop service
sudo systemctl stop n8n-local.service

# Update N8N-R8 code/configuration
git pull  # or your update method

# Update Docker images
docker compose pull

# Start service
sudo systemctl start n8n-local.service
```

### Service File Updates

```bash
# After modifying service files
sudo systemctl daemon-reload
sudo systemctl restart n8n-local.service
```

### Backup Service Configuration

```bash
# Backup current service files
sudo cp /etc/systemd/system/n8n-*.service ~/systemd-backup/

# Restore if needed
sudo cp ~/systemd-backup/n8n-*.service /etc/systemd/system/
sudo systemctl daemon-reload
```

## 🚀 Production Deployment

### Recommended Production Setup

1. **Use Traefik service** for automatic SSL
2. **Enable monitoring service** for observability
3. **Set up log rotation** for systemd logs
4. **Configure resource limits** based on your system
5. **Enable automatic updates** with proper testing

### Production Checklist

- [ ] Service files customized for your environment
- [ ] SSL certificates configured (for Traefik/Nginx)
- [ ] Monitoring and alerting set up
- [ ] Log rotation configured
- [ ] Backup strategy implemented
- [ ] Resource limits set appropriately
- [ ] Security hardening applied
- [ ] Update process documented

---

For more information about N8N-R8 configuration and management, see the main [README.md](../README.md) file.
