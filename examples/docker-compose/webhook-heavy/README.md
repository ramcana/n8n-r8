# Webhook-Heavy N8N Setup

This configuration is optimized for applications that handle a high volume of webhooks and API requests.

## 🚀 Features

- **High-Performance Configuration**: Optimized for webhook processing
- **Advanced Rate Limiting**: Different limits for webhooks, API, and UI
- **Load Balancing**: Nginx with upstream configuration
- **Enhanced Monitoring**: Request timing and performance metrics
- **Scalable Database**: PostgreSQL tuned for high concurrency
- **Redis Optimization**: Configured for queue processing

## 📋 Requirements

- Docker and Docker Compose
- At least 4GB RAM recommended
- 2+ CPU cores for optimal performance

## 🔧 Setup Instructions

### 1. Copy Configuration
```bash
cp .env.example .env
```

### 2. Configure Environment
Edit `.env` file with your settings:
- Database credentials
- Redis password
- N8N encryption keys
- Domain/host configuration

### 3. Create Data Directories
```bash
mkdir -p data/{n8n,postgres,redis,nginx/logs}
```

### 4. Start Services
```bash
docker compose up -d
```

### 5. Verify Setup
```bash
# Check all services are running
docker compose ps

# Check N8N logs
docker compose logs n8n

# Test webhook endpoint
curl -X POST http://localhost/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## 🔍 Performance Optimizations

### N8N Optimizations
- **Queue Mode**: Uses Redis for job queuing
- **Memory**: 4GB heap size allocation
- **Payload Size**: 16MB maximum webhook payload
- **Timeout**: 5-minute webhook processing timeout
- **Thread Pool**: 16 threads for concurrent processing

### PostgreSQL Optimizations
- **Connections**: Up to 500 concurrent connections
- **Memory**: 512MB shared buffers, 2GB effective cache
- **Workers**: 16 worker processes with parallel query support
- **WAL**: Optimized write-ahead logging configuration

### Redis Optimizations
- **Memory**: 1GB maximum with LRU eviction
- **Persistence**: AOF + RDB snapshots
- **Keepalive**: TCP keepalive for connection stability

### Nginx Optimizations
- **Rate Limiting**: 
  - Webhooks: 100 req/s with 200 burst
  - API: 50 req/s with 100 burst
  - General: 10 req/s with 20 burst
- **Connections**: 20 per IP, 1000 per server
- **Buffers**: Large buffers for webhook payloads
- **Timeouts**: Extended timeouts for processing

## 📊 Monitoring

### Health Checks
```bash
# Check service health
curl http://localhost/health

# Check N8N health
curl http://localhost:5678/healthz
```

### Performance Monitoring
```bash
# Nginx access logs with timing
docker compose logs nginx

# Database connections
docker compose exec postgres psql -U n8n_user -d n8n_webhook -c "SELECT count(*) FROM pg_stat_activity;"

# Redis memory usage
docker compose exec redis redis-cli info memory
```

### Log Analysis
```bash
# Real-time webhook requests
docker compose logs -f nginx | grep webhook

# N8N execution logs
docker compose logs -f n8n | grep execution

# Database performance
docker compose logs -f postgres | grep "duration:"
```

## 🔧 Tuning Guidelines

### For Higher Traffic
Increase these values in docker-compose.yml:

```yaml
# N8N
NODE_OPTIONS: --max-old-space-size=8192
UV_THREADPOOL_SIZE: 32

# PostgreSQL
max_connections: 1000
shared_buffers: 1GB
work_mem: 16MB

# Redis
maxmemory: 2gb
```

### For Lower Resource Usage
Decrease these values:

```yaml
# N8N
NODE_OPTIONS: --max-old-space-size=2048
UV_THREADPOOL_SIZE: 8

# PostgreSQL
max_connections: 200
shared_buffers: 256MB
work_mem: 4MB
```

## 🚨 Troubleshooting

### High Memory Usage
```bash
# Check container memory usage
docker stats

# Reduce N8N memory limit
NODE_OPTIONS: --max-old-space-size=2048
```

### Webhook Timeouts
```bash
# Increase timeout values
WEBHOOK_TIMEOUT: 600000  # 10 minutes
N8N_WEBHOOK_WAIT_TIME: 300000  # 5 minutes
```

### Database Connection Issues
```bash
# Check active connections
docker compose exec postgres psql -U n8n_user -d n8n_webhook -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"

# Increase connection limit if needed
max_connections: 800
```

### Rate Limiting Issues
```bash
# Check Nginx error logs
docker compose logs nginx | grep "limiting requests"

# Adjust rate limits in nginx.conf
limit_req_zone $binary_remote_addr zone=webhook:10m rate=200r/s;
```

## 📈 Scaling Recommendations

### Horizontal Scaling
- Use multiple N8N instances behind a load balancer
- Implement Redis Cluster for queue distribution
- Use PostgreSQL read replicas for reporting

### Vertical Scaling
- Increase CPU cores (4+ recommended)
- Add more RAM (8GB+ for high traffic)
- Use SSD storage for database and Redis

### Network Optimization
- Use CDN for static assets
- Implement connection pooling
- Configure TCP optimization

## 🔒 Security Considerations

- Change all default passwords
- Use HTTPS in production
- Implement proper firewall rules
- Regular security updates
- Monitor access logs for suspicious activity

## 📚 Additional Resources

- [N8N Performance Guide](https://docs.n8n.io/hosting/scaling/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Redis Performance Best Practices](https://redis.io/docs/management/optimization/)
- [Nginx Performance Tuning](https://www.nginx.com/blog/tuning-nginx/)
