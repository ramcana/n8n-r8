# N8N-R8 Examples

This directory contains example configurations, workflows, and use cases for the N8N-R8 project.

## 📁 Directory Structure

```
examples/
├── docker-compose/          # Docker Compose variations
│   ├── webhook-heavy/       # High-traffic webhook setup
│   ├── development/         # Development environment
│   └── production/          # Production-ready setup
├── workflows/               # Sample N8N workflows
│   ├── basic/              # Basic automation examples
│   ├── integrations/       # Third-party integrations
│   └── advanced/           # Complex workflow patterns
├── configurations/         # Configuration examples
│   ├── nginx/              # Nginx configurations
│   ├── monitoring/         # Monitoring setups
│   └── security/           # Security configurations
└── use-cases/              # Real-world use cases
    ├── data-processing/    # Data transformation examples
    ├── notifications/      # Notification systems
    └── api-integrations/   # API integration patterns
```

## 🚀 Quick Start Examples

### 1. Webhook-Heavy Setup
For applications that handle many webhooks:
```bash
cd examples/docker-compose/webhook-heavy/
docker compose up -d
```

### 2. Development Environment
For local development with hot-reload:
```bash
cd examples/docker-compose/development/
docker compose up -d
```

### 3. Production Setup
For production deployment with all monitoring:
```bash
cd examples/docker-compose/production/
docker compose up -d
```

## 📋 Available Examples

### Docker Compose Variations
- **webhook-heavy**: Optimized for high webhook traffic
- **development**: Development environment with debugging
- **production**: Full production setup with monitoring

### Sample Workflows
- **basic**: Simple automation workflows
- **integrations**: Popular service integrations
- **advanced**: Complex multi-step workflows

### Configuration Examples
- **nginx**: Various Nginx configurations
- **monitoring**: Different monitoring setups
- **security**: Security hardening examples

## 🔧 Usage Instructions

Each example directory contains:
- `README.md` - Specific instructions
- `docker-compose.yml` - Docker configuration
- `.env.example` - Environment variables
- Configuration files as needed

To use an example:
1. Copy the example directory
2. Rename `.env.example` to `.env`
3. Modify configuration as needed
4. Run `docker compose up -d`

## 📖 Documentation

See individual README files in each example directory for detailed instructions and explanations.
