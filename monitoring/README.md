# N8N-R8 Monitoring System

A comprehensive monitoring solution for the N8N-R8 development environment, providing health checks, metrics collection, alerting, and visualization.

## 🚀 Features

- **Multi-level Monitoring**: Basic script-based monitoring to full Prometheus/Grafana stack
- **Health Checks**: Automated service health monitoring with customizable thresholds
- **Disk Space Monitoring**: Proactive disk usage monitoring with cleanup automation
- **Log Management**: Automated log rotation and retention
- **Email Alerts**: Configurable email notifications for critical issues
- **External Integrations**: Support for Slack, Discord, PagerDuty, and more
- **Metrics Collection**: Prometheus-based metrics with Grafana visualization
- **Uptime Monitoring**: Website and service availability tracking

## 📁 Directory Structure

```
monitoring/
├── scripts/
│   ├── monitor.sh              # Main monitoring script
│   ├── disk-monitor.sh         # Disk space monitoring
│   └── start-monitoring.sh     # Monitoring system startup
├── config/
│   ├── monitor.conf            # Monitoring configuration
│   ├── prometheus.yml          # Prometheus configuration
│   ├── alert_rules.yml         # Prometheus alert rules
│   ├── alertmanager.yml        # Alertmanager configuration
│   └── logrotate.conf          # Log rotation configuration
├── logs/                       # Monitoring logs
├── data/                       # Persistent data for monitoring services
└── README.md                   # This file
```

## ⚡ Quick Start

### 1. Basic Monitoring (Recommended for Development)

Start simple script-based monitoring:

```bash
# One-time health check
./monitoring/scripts/monitor.sh check

# Start continuous monitoring
./scripts/start-monitoring.sh basic -d

# Check disk usage
./monitoring/scripts/disk-monitor.sh check
```

### 2. Full Monitoring Stack (Recommended for Production)

Start the complete monitoring stack with Prometheus, Grafana, and Alertmanager:

```bash
# Start full monitoring stack
./scripts/start-monitoring.sh full -d

# Access monitoring interfaces
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000 (admin/admin)
# Alertmanager: http://localhost:9093
```

### 3. Minimal Monitoring (Lightweight Option)

Start essential monitoring services only:

```bash
./scripts/start-monitoring.sh minimal -d
```

## 🔧 Configuration

### Basic Configuration

Edit `monitoring/config/monitor.conf` to customize monitoring behavior:

```bash
# Check interval in seconds
CHECK_INTERVAL=30

# Disk usage threshold percentage
DISK_THRESHOLD=85

# Memory usage threshold percentage  
MEMORY_THRESHOLD=90

# Enable email alerts
ENABLE_EMAIL_ALERTS=true
EMAIL_TO="admin@example.com"
```

### Email Alerts Setup

1. **Configure SMTP settings** in `monitor.conf`:
```bash
ENABLE_EMAIL_ALERTS=true
EMAIL_TO="your-email@example.com"
EMAIL_FROM="n8n-monitor@localhost"
SMTP_SERVER="localhost"
```

2. **Install mail system** (Ubuntu/Debian):
```bash
sudo apt-get install mailutils postfix
```

3. **Test email alerts**:
```bash
./monitoring/scripts/monitor.sh test-alert
```

### External Monitoring Integration

#### Slack Integration

1. Create a Slack webhook URL
2. Update `monitoring/config/alertmanager.yml`:
```yaml
slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
    channel: '#alerts'
```

#### Discord Integration

1. Create a Discord webhook URL
2. Update `monitoring/config/alertmanager.yml`:
```yaml
discord_configs:
  - webhook_url: 'https://discord.com/api/webhooks/YOUR/WEBHOOK'
```

#### PagerDuty Integration

1. Get your PagerDuty integration key
2. Update `monitoring/config/alertmanager.yml`:
```yaml
pagerduty_configs:
  - routing_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'
```

## 📊 Monitoring Components

### 1. Health Check Monitoring

**What it monitors:**
- Service availability (N8N, PostgreSQL, Redis, Nginx/Traefik)
- HTTP endpoint responses
- Container health status
- System resources (CPU, Memory, Disk)

**Usage:**
```bash
# Manual health check
./monitoring/scripts/monitor.sh check

# Start continuous monitoring
./monitoring/scripts/monitor.sh monitor -d

# Check specific service status
./monitoring/scripts/monitor.sh status
```

### 2. Disk Space Monitoring

**What it monitors:**
- Data directory usage
- Backup directory size
- Docker system space usage
- Individual container disk usage

**Usage:**
```bash
# Check disk usage
./monitoring/scripts/disk-monitor.sh check

# Generate detailed report
./monitoring/scripts/disk-monitor.sh report

# Clean up old files
./monitoring/scripts/disk-monitor.sh cleanup

# Start continuous monitoring
./monitoring/scripts/disk-monitor.sh monitor
```

### 3. Prometheus Metrics

**Metrics collected:**
- System metrics (CPU, Memory, Disk, Network)
- Container metrics (Resource usage, Health status)
- N8N application metrics (if enabled)
- HTTP endpoint availability
- Custom business metrics

**Access:** http://localhost:9090

### 4. Grafana Dashboards

**Pre-configured dashboards:**
- System Overview
- Container Metrics
- N8N Application Metrics
- Network and Storage
- Alert Status

**Access:** http://localhost:3000 (admin/admin)

### 5. Log Management

**Features:**
- Automatic log rotation
- Configurable retention periods
- Centralized log collection with Loki
- Log analysis and search

**Configuration:** `monitoring/config/logrotate.conf`

## 🚨 Alerting

### Alert Types

1. **Critical Alerts** (Immediate attention required)
   - Service down
   - Disk space >95%
   - Memory usage >95%
   - HTTP endpoints unreachable

2. **Warning Alerts** (Should be addressed soon)
   - High resource usage
   - Disk space >85%
   - Service performance degradation

3. **Maintenance Alerts** (Informational)
   - Backup status
   - Log volume changes
   - Predictive alerts

### Alert Channels

- **Email**: Basic email notifications
- **Slack**: Team chat integration
- **Discord**: Community notifications
- **PagerDuty**: On-call management
- **Webhook**: Custom integrations

### Customizing Alerts

Edit `monitoring/config/alert_rules.yml` to modify alert conditions:

```yaml
- alert: HighDiskUsage
  expr: (node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100 > 80
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High disk usage detected"
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Monitoring Script Not Starting
```bash
# Check permissions
chmod +x monitoring/scripts/*.sh

# Check logs
tail -f monitoring/logs/monitor.log

# Test manually
./monitoring/scripts/monitor.sh check
```

#### 2. Email Alerts Not Working
```bash
# Test email system
echo "Test" | mail -s "Test" your-email@example.com

# Check mail logs
tail -f /var/log/mail.log

# Test monitoring email
./monitoring/scripts/monitor.sh test-alert
```

#### 3. Prometheus Not Scraping Metrics
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify service endpoints
curl http://localhost:9100/metrics  # Node exporter
curl http://localhost:8080/metrics  # cAdvisor
```

#### 4. High Resource Usage
```bash
# Check container resources
docker stats

# Review monitoring configuration
vim monitoring/config/monitor.conf

# Adjust check intervals
CHECK_INTERVAL=60  # Increase interval
```

### Log Locations

- **Monitoring logs**: `monitoring/logs/monitor.log`
- **Disk monitoring**: `monitoring/logs/disk-monitor.log`
- **Alert history**: `monitoring/logs/alerts.log`
- **Service logs**: `docker compose logs <service>`

## 📈 Performance Tuning

### For High-Load Environments

1. **Increase check intervals**:
```bash
CHECK_INTERVAL=60  # Check every minute instead of 30 seconds
```

2. **Adjust alert thresholds**:
```bash
DISK_THRESHOLD=90     # Increase disk threshold
MEMORY_THRESHOLD=95   # Increase memory threshold
```

3. **Optimize Prometheus retention**:
```yaml
# In prometheus.yml
--storage.tsdb.retention.time=15d  # Reduce retention
```

4. **Use external monitoring**:
   - Datadog
   - New Relic
   - AWS CloudWatch
   - Google Cloud Monitoring

## 🔗 External Monitoring Setup

### Datadog Integration

1. **Install Datadog agent**:
```bash
DD_API_KEY=your-api-key bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"
```

2. **Configure Docker monitoring**:
```yaml
# Add to docker-compose.yml
labels:
  - "com.datadoghq.ad.check_names=[\"docker\"]"
  - "com.datadoghq.ad.init_configs=[{}]"
```

### New Relic Integration

1. **Install New Relic agent**:
```bash
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash
sudo NEW_RELIC_API_KEY=your-api-key NEW_RELIC_ACCOUNT_ID=your-account-id /usr/local/bin/newrelic install
```

### AWS CloudWatch

1. **Install CloudWatch agent**:
```bash
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
```

2. **Configure metrics collection**:
```json
{
  "metrics": {
    "namespace": "N8N-R8",
    "metrics_collected": {
      "cpu": {"measurement": ["cpu_usage_idle", "cpu_usage_iowait"]},
      "disk": {"measurement": ["used_percent"], "resources": ["*"]},
      "mem": {"measurement": ["mem_used_percent"]}
    }
  }
}
```

## 🛠️ Advanced Configuration

### Custom Health Checks

Add custom health check URLs in `monitor.conf`:

```bash
CUSTOM_HEALTH_URLS="http://api.example.com/health http://service.example.com/status"
```

### Webhook Integration

Create custom webhook receivers:

```bash
# Example webhook server (Python)
from flask import Flask, request
app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    # Process alert data
    return 'OK'

app.run(port=5001)
```

### Backup Monitoring

Monitor backup operations:

```bash
# Add to crontab for backup monitoring
0 3 * * * /path/to/n8n-r8/scripts/backup.sh && echo "$(date): Backup completed" >> /var/log/backup.log
```

## 📚 Best Practices

1. **Start Simple**: Begin with basic monitoring and gradually add complexity
2. **Set Appropriate Thresholds**: Avoid alert fatigue with realistic thresholds
3. **Regular Testing**: Test alert systems regularly
4. **Monitor the Monitors**: Ensure monitoring systems are healthy
5. **Document Changes**: Keep monitoring configuration documented
6. **Review Regularly**: Periodically review and update monitoring rules

## 🔄 Maintenance

### Regular Tasks

1. **Weekly**:
   - Review alert history
   - Check disk usage trends
   - Verify backup operations

2. **Monthly**:
   - Update monitoring thresholds
   - Review and clean old logs
   - Test disaster recovery procedures

3. **Quarterly**:
   - Update monitoring stack versions
   - Review and optimize alert rules
   - Conduct monitoring system health check

### Updating the Monitoring Stack

```bash
# Update Docker images
docker compose -f docker-compose.monitoring.yml pull

# Restart with new images
./scripts/start-monitoring.sh full --build -d

# Verify all services are healthy
docker compose -f docker-compose.monitoring.yml ps
```

---

For additional help or questions about the monitoring system, check the logs in `monitoring/logs/` or run the health check script for diagnostic information.
