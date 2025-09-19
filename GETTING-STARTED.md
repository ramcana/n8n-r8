# Getting Started with N8N-R8

Welcome to N8N-R8! This guide will help you get up and running quickly with the right configuration for your needs.

## 🚀 Quick Start Options

Choose the setup that best matches your use case:

### 1. **Basic Setup** (Recommended for beginners)
```bash
# Copy environment file
cp .env.example .env

# Edit configuration (set passwords, domains, etc.)
nano .env

# Start basic N8N setup
make quick-start
```
**Access**: http://localhost:5678

### 2. **Development Environment** (For developers)
```bash
# Start development environment with debugging tools
make quick-dev-full
```
**Includes**: N8N + PostgreSQL + Redis + PgAdmin + Custom Node Development
**Access**: 
- N8N: http://localhost:5678
- PgAdmin: http://localhost:8080
- Direct DB: localhost:5432

### 3. **Webhook-Heavy Setup** (For production with high traffic)
```bash
# Start high-performance webhook configuration
make quick-webhook-heavy
```
**Optimized for**: 100+ webhooks/second, high concurrency
**Access**: http://localhost (via Nginx)

### 4. **Production with Monitoring** (Full production setup)
```bash
# Start with security and monitoring
make quick-full
```
**Includes**: N8N + Security + Monitoring Stack + Alerts

## 📋 Prerequisites

- **Docker** and **Docker Compose** installed
- **2GB+ RAM** (4GB+ recommended for webhook-heavy)
- **2+ CPU cores** (recommended)
- **10GB+ disk space**

### Quick Docker Installation
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Restart your shell or logout/login
```

## ⚙️ Configuration

### Environment Setup
1. **Copy the example environment file**:
   ```bash
   cp .env.example .env
   ```

2. **Edit key settings**:
   ```bash
   nano .env
   ```

3. **Essential variables to configure**:
   ```bash
   # Database credentials
   POSTGRES_PASSWORD=your_secure_password_here
   
   # N8N authentication
   N8N_BASIC_AUTH_USER=admin
   N8N_BASIC_AUTH_PASSWORD=your_admin_password
   
   # Security keys (generate random 32-character strings)
   N8N_ENCRYPTION_KEY=your_32_character_encryption_key
   N8N_JWT_SECRET=your_jwt_secret_here
   
   # Domain configuration (for production)
   N8N_HOST=your-domain.com
   WEBHOOK_URL=https://your-domain.com/
   ```

### Security Best Practices
```bash
# Generate secure passwords
openssl rand -base64 32

# Generate encryption key
openssl rand -hex 16

# Initialize security framework
make security-init
```

## 🎯 Use Case Scenarios

### Scenario 1: Personal Automation
**Best Setup**: Basic Setup
```bash
make quick-start
```
- Simple workflows and personal automations
- Low to medium traffic
- Easy to manage and maintain

### Scenario 2: Development & Testing
**Best Setup**: Development Environment
```bash
make quick-dev-full
```
- Custom node development
- Workflow testing and debugging
- Database access for development
- Hot-reload for custom nodes

### Scenario 3: Business Webhooks
**Best Setup**: Webhook-Heavy Configuration
```bash
make quick-webhook-heavy
```
- High-volume webhook processing
- API integrations
- Production workloads
- Advanced rate limiting and performance tuning

### Scenario 4: Enterprise Deployment
**Best Setup**: Full Production Setup
```bash
make quick-full
```
- Complete monitoring and alerting
- Security hardening
- Backup and recovery
- Performance monitoring

## 🛠️ Common Commands

### Basic Operations
```bash
# Start services
make start

# Stop services
make stop

# View logs
make logs

# Check status
make status

# Health check
make health
```

### Development
```bash
# Build custom nodes
make build-nodes

# Watch mode for node development
make watch-nodes

# Test custom nodes
make test-nodes
```

### Maintenance
```bash
# Create backup
make backup

# Update services
make update

# Clean up resources
make clean
```

### Monitoring
```bash
# Start monitoring
make monitor-full

# Check performance
make performance-baseline

# View monitoring logs
make monitor-logs
```

## 🔧 Configuration Examples

### Basic Configuration (.env)
```bash
# Database
POSTGRES_DB=n8n
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=secure_password_123

# N8N
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=admin_password_123
N8N_ENCRYPTION_KEY=your_32_character_encryption_key
N8N_HOST=localhost
WEBHOOK_URL=http://localhost:5678/
```

### Production Configuration (.env)
```bash
# Database
POSTGRES_DB=n8n_prod
POSTGRES_USER=n8n_prod_user
POSTGRES_PASSWORD=very_secure_production_password

# N8N
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=very_secure_admin_password
N8N_ENCRYPTION_KEY=production_32_character_encryption_key
N8N_HOST=your-domain.com
WEBHOOK_URL=https://your-domain.com/
N8N_PROTOCOL=https
N8N_SECURE_COOKIE=true

# Security
N8N_LOG_LEVEL=info
NODE_ENV=production
```

## 🚨 Troubleshooting

### Common Issues

#### Services won't start
```bash
# Check Docker status
docker info

# Check environment file
make check-env

# View detailed logs
make logs
```

#### Port conflicts
```bash
# Check what's using the port
sudo netstat -tulpn | grep :5678

# Use different port in .env
N8N_PORT=5679
```

#### Permission issues
```bash
# Fix permissions
make setup

# Or manually
chmod +x scripts/*.sh
sudo chown -R $USER:$USER data/
```

#### Database connection issues
```bash
# Check database logs
make logs-postgres

# Reset database
make reset
```

### Performance Issues

#### High memory usage
```bash
# Check resource usage
docker stats

# Reduce memory limits in docker-compose.yml
NODE_OPTIONS=--max-old-space-size=2048
```

#### Slow webhook processing
```bash
# Use webhook-heavy configuration
make start-webhook-heavy

# Or tune existing setup
# Increase worker processes in nginx.conf
# Increase database connections
# Add Redis for queuing
```

## 📚 Next Steps

### Learning Path
1. **Start with Basic Setup** - Get familiar with N8N interface
2. **Create Simple Workflows** - Use built-in nodes
3. **Explore Examples** - Check `examples/workflows/` directory
4. **Custom Node Development** - Build your own integrations
5. **Production Deployment** - Scale and secure your setup

### Useful Resources
- **N8N Documentation**: https://docs.n8n.io/
- **Community Forum**: https://community.n8n.io/
- **Example Workflows**: `examples/workflows/`
- **Custom Node Guide**: `nodes/README.md`
- **Performance Tuning**: `docs/performance/`

### Advanced Features
```bash
# Enable autoupdate
make autoupdate-enable

# Set up monitoring
make monitor-full

# Configure SSL/TLS
make start-traefik

# Security hardening
make security-init
```

## 🤝 Getting Help

### Documentation
- **Main README**: `README.md`
- **Custom Nodes**: `nodes/README.md`
- **Examples**: `examples/README.md`
- **Improvements**: `IMPROVEMENTS-IMPLEMENTED.md`

### Commands
```bash
# Show all available commands
make help

# Show configuration info
make info

# Show access URLs
make urls
```

### Support
- Check the `docs/` directory for detailed documentation
- Review example configurations in `examples/`
- Look at troubleshooting guides in individual README files
- Check the N8N community forum for general N8N questions

## 🎉 You're Ready!

Choose your setup and get started:

```bash
# For beginners
make quick-start

# For developers  
make quick-dev-full

# For high-traffic production
make quick-webhook-heavy

# For enterprise deployment
make quick-full
```

Welcome to the world of workflow automation with N8N-R8! 🚀
