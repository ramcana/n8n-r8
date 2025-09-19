# N8N-R8 Autoupdate System

The N8N-R8 project includes a comprehensive autoupdate system that provides automated container updates with backup integration, rollback capabilities, and notification support.

## Features

- ✅ **Automated Updates**: Using Watchtower or scheduled scripts
- ✅ **Backup Integration**: Automatic backup before updates
- ✅ **Rollback Capability**: Automatic rollback on update failure
- ✅ **Notification System**: Slack and email notifications
- ✅ **Flexible Scheduling**: Cron-based or Watchtower scheduling
- ✅ **Safety Features**: Health checks and graceful rollbacks
- ✅ **Configuration Options**: Extensive customization options

## Quick Start

### 1. Enable Autoupdate

```bash
# Enable autoupdate functionality
make autoupdate-enable

# Check status
make autoupdate-status
```

### 2. Configure Settings

Copy the autoupdate configuration template:

```bash
cp .env.autoupdate.example .env.additional
cat .env.additional >> .env
```

Edit your `.env` file to configure autoupdate settings:

```bash
# Basic settings
AUTOUPDATE_ENABLED=true
BACKUP_BEFORE_UPDATE=true
ROLLBACK_ON_FAILURE=true

# Notification settings (optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
NOTIFICATION_EMAIL=admin@yourdomain.com
```

### 3. Choose Update Method

#### Option A: Watchtower (Recommended)

Start N8N with Watchtower for fully automated updates:

```bash
make start-with-autoupdate
```

#### Option B: Scheduled Updates

Install a cron job for scheduled updates:

```bash
make autoupdate-schedule
```

#### Option C: Manual Updates

Perform manual updates when needed:

```bash
make autoupdate-update
```

## Update Methods

### 1. Watchtower Method

Watchtower monitors your containers and automatically updates them when new images are available.

**Advantages:**
- Fully automated
- Real-time monitoring
- Rolling updates (one container at a time)
- Built-in notifications

**Configuration:**
```bash
# Start with Watchtower
docker compose -f docker-compose.yml -f docker-compose.autoupdate.yml up -d

# Or use the Makefile command
make start-with-autoupdate
```

**Watchtower Settings:**
- **Schedule**: Daily at 2 AM (configurable)
- **Rolling Updates**: Updates one container at a time
- **Cleanup**: Removes old images after update
- **Notifications**: Slack and email support

### 2. Scheduled Script Method

Uses the autoupdate script with cron scheduling for more control.

**Advantages:**
- More control over update process
- Custom backup integration
- Advanced rollback capabilities
- Detailed logging

**Configuration:**
```bash
# Install cron job (daily at 2 AM by default)
make autoupdate-schedule

# Custom schedule in .env
AUTOUPDATE_CRON_SCHEDULE="0 2 * * *"  # Daily at 2 AM
AUTOUPDATE_CRON_SCHEDULE="0 2 * * 0"  # Weekly on Sunday at 2 AM
```

### 3. Manual Updates

For controlled, on-demand updates.

```bash
# Check for updates
make autoupdate-check

# Perform update
make autoupdate-update

# Force update (skip checks)
./scripts/autoupdate.sh update --force
```

## Configuration Options

### Basic Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `AUTOUPDATE_ENABLED` | `false` | Enable/disable autoupdate |
| `BACKUP_BEFORE_UPDATE` | `true` | Create backup before update |
| `ROLLBACK_ON_FAILURE` | `true` | Rollback on update failure |
| `MAX_BACKUP_RETENTION` | `7` | Days to keep backups |
| `UPDATE_CHECK_INTERVAL` | `86400` | Update check interval (seconds) |

### Watchtower Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `WATCHTOWER_POLL_INTERVAL` | `86400` | Check interval (seconds) |
| `WATCHTOWER_SCHEDULE` | `0 0 2 * * *` | Cron schedule |
| `WATCHTOWER_CLEANUP` | `true` | Remove old images |
| `WATCHTOWER_ROLLING_RESTART` | `true` | Rolling updates |

### Notification Settings

| Setting | Description |
|---------|-------------|
| `NOTIFICATION_ENABLED` | Enable notifications |
| `SLACK_WEBHOOK_URL` | Slack webhook URL |
| `NOTIFICATION_EMAIL` | Email for notifications |
| `SMTP_SERVER` | SMTP server for email |

## Safety Features

### 1. Backup Integration

Automatic backup creation before updates:

```bash
# Backups are created in ./backups/ directory
# Format: pre-update-YYYYMMDD_HHMMSS.tar.gz
```

### 2. Health Checks

Post-update health verification:

- Container health status
- Service availability
- Database connectivity
- Application responsiveness

### 3. Rollback Capability

Automatic rollback on failure:

```bash
# Rollback is triggered if:
# - Container fails to start
# - Health checks fail
# - Services become unresponsive
```

### 4. Logging

Comprehensive logging system:

```bash
# View autoupdate logs
tail -f logs/autoupdate.log

# View Watchtower logs
docker compose logs watchtower
```

## Commands Reference

### Makefile Commands

```bash
# Status and configuration
make autoupdate-status          # Show current status
make autoupdate-check          # Check for updates

# Enable/disable
make autoupdate-enable         # Enable autoupdate
make autoupdate-disable        # Disable autoupdate

# Update operations
make autoupdate-update         # Manual update
make autoupdate-watchtower     # Watchtower update
make autoupdate-schedule       # Install cron job

# Start with autoupdate
make start-with-autoupdate     # Start with Watchtower
```

### Script Commands

```bash
# Basic operations
./scripts/autoupdate.sh status
./scripts/autoupdate.sh check
./scripts/autoupdate.sh update
./scripts/autoupdate.sh enable
./scripts/autoupdate.sh disable

# Advanced options
./scripts/autoupdate.sh update --force --no-backup
./scripts/autoupdate.sh watchtower
./scripts/autoupdate.sh schedule
```

## Notification Setup

### Slack Notifications

1. Create a Slack webhook:
   - Go to https://api.slack.com/apps
   - Create new app → Incoming Webhooks
   - Copy webhook URL

2. Configure in `.env`:
   ```bash
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
   WATCHTOWER_SLACK_CHANNEL=#alerts
   ```

### Email Notifications

Configure SMTP settings in `.env`:

```bash
NOTIFICATION_EMAIL=admin@yourdomain.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

## Troubleshooting

### Common Issues

1. **Updates not running**
   ```bash
   # Check if autoupdate is enabled
   make autoupdate-status
   
   # Check cron job
   crontab -l | grep autoupdate
   ```

2. **Backup failures**
   ```bash
   # Check backup script permissions
   ls -la scripts/backup.sh
   
   # Test backup manually
   ./scripts/backup.sh --test
   ```

3. **Notification issues**
   ```bash
   # Test Slack webhook
   curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"Test message"}' \
        $SLACK_WEBHOOK_URL
   ```

4. **Watchtower not updating**
   ```bash
   # Check Watchtower logs
   docker compose logs watchtower
   
   # Verify container labels
   docker inspect n8n | grep watchtower
   ```

### Log Files

- **Autoupdate logs**: `logs/autoupdate.log`
- **Watchtower logs**: `docker compose logs watchtower`
- **Backup logs**: `logs/backup.log`

### Recovery Procedures

1. **Manual rollback**:
   ```bash
   # List available backups
   ls -la backups/pre-update-*
   
   # Restore from backup
   ./scripts/restore.sh pre-update-20240101_120000
   ```

2. **Reset autoupdate**:
   ```bash
   # Disable and re-enable
   make autoupdate-disable
   make autoupdate-enable
   ```

## Best Practices

### 1. Testing Updates

- Use a staging environment first
- Test updates during low-traffic periods
- Monitor logs during and after updates

### 2. Backup Strategy

- Keep multiple backup generations
- Test restore procedures regularly
- Store backups in multiple locations

### 3. Notification Strategy

- Set up multiple notification channels
- Include relevant team members
- Configure appropriate alert levels

### 4. Scheduling

- Schedule updates during maintenance windows
- Avoid peak usage times
- Consider time zones for global deployments

### 5. Monitoring

- Monitor update success/failure rates
- Track update duration
- Monitor system performance post-update

## Security Considerations

1. **Webhook Security**: Protect Slack webhook URLs
2. **Email Security**: Use app passwords, not account passwords
3. **Backup Security**: Encrypt sensitive backup data
4. **Access Control**: Limit who can modify autoupdate settings

## Advanced Configuration

### Custom Update Commands

```bash
# Pre/post update hooks
PRE_UPDATE_COMMAND="./scripts/maintenance-mode.sh enable"
POST_UPDATE_COMMAND="./scripts/maintenance-mode.sh disable"
```

### Maintenance Mode

```bash
# Enable maintenance mode during updates
MAINTENANCE_MODE_ENABLED=true
MAINTENANCE_MESSAGE="N8N is being updated. Please try again in a few minutes."
```

### Custom Backup Directory

```bash
# Use custom backup location
CUSTOM_BACKUP_DIR="/mnt/backups/n8n"
```

## Integration with CI/CD

The autoupdate system can be integrated with CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Deploy and Update N8N
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Update
        run: |
          ssh user@server 'cd /path/to/n8n-r8 && make autoupdate-update'
```

## Support

For issues or questions about the autoupdate system:

1. Check the troubleshooting section above
2. Review log files for error messages
3. Test individual components (backup, restore, notifications)
4. Consult the N8N documentation for container-specific issues

## Changelog

- **v1.0.0**: Initial autoupdate system implementation
  - Watchtower integration
  - Backup and rollback capabilities
  - Notification system
  - Comprehensive configuration options
