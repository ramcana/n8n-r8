# Development Environment

This setup provides a complete development environment for N8N-R8 with debugging tools and development-friendly configurations.

## 🚀 Features

- **Development Mode**: Debug logging and development settings
- **Database Access**: PostgreSQL exposed on port 5432
- **Custom Node Development**: Hot-reload for custom nodes
- **Database Admin**: Optional PgAdmin interface
- **Queue Testing**: Optional Redis for testing queue functionality
- **Workflow Persistence**: Local workflow and credential storage

## 🔧 Quick Start

### 1. Setup Environment
```bash
cp .env.example .env
# Edit .env with your preferences (defaults work for development)
```

### 2. Create Directories
```bash
mkdir -p data/{n8n,postgres,redis,pgadmin}
mkdir -p {workflows,credentials}
```

### 3. Start Basic Development Environment
```bash
docker compose up -d
```

### 4. Start with Optional Services
```bash
# With custom node development
docker compose --profile dev up -d

# With database admin interface
docker compose --profile admin up -d

# With Redis for queue testing
docker compose --profile queue up -d

# All services
docker compose --profile dev --profile admin --profile queue up -d
```

## 🛠️ Development Workflow

### Custom Node Development
1. **Start Node Development Container**:
   ```bash
   docker compose --profile dev up -d
   ```

2. **Edit Nodes**: Modify files in `../../nodes/src/`

3. **Auto-Build**: Changes are automatically compiled and available in N8N

4. **Test**: Restart N8N to load new nodes:
   ```bash
   docker compose restart n8n
   ```

### Database Development
1. **Direct Access**:
   ```bash
   # Connect to PostgreSQL directly
   psql -h localhost -p 5432 -U n8n_dev_user -d n8n_dev
   ```

2. **Using PgAdmin**:
   - Start with admin profile: `docker compose --profile admin up -d`
   - Access at http://localhost:8080
   - Login with credentials from .env file
   - Add server: localhost:5432

### Workflow Development
1. **Create Workflows**: Use N8N UI at http://localhost:5678
2. **Export/Import**: Workflows saved in `./workflows/` directory
3. **Version Control**: Commit workflow files to git
4. **Sharing**: Share workflow files with team members

## 📊 Development Tools

### Accessing Services
- **N8N Interface**: http://localhost:5678
- **PgAdmin** (if enabled): http://localhost:8080
- **PostgreSQL**: localhost:5432
- **Redis** (if enabled): localhost:6379

### Debugging
```bash
# View N8N logs with debug information
docker compose logs -f n8n

# View database queries
docker compose logs -f postgres

# Check custom node compilation
docker compose logs -f n8n-node-dev

# Monitor all services
docker compose logs -f
```

### Database Queries
```sql
-- View all workflows
SELECT id, name, active, created_at FROM workflow_entity;

-- View executions
SELECT id, workflow_id, mode, started_at, finished_at, status 
FROM execution_entity 
ORDER BY started_at DESC 
LIMIT 10;

-- View credentials
SELECT id, name, type, created_at FROM credentials_entity;
```

### Testing Custom Nodes
1. **Build Node**:
   ```bash
   cd ../../nodes
   npm run build
   ```

2. **Restart N8N**:
   ```bash
   docker compose restart n8n
   ```

3. **Check Node Loading**:
   ```bash
   docker compose logs n8n | grep -i "custom\|node"
   ```

## 🔧 Configuration Options

### Environment Profiles
- **Default**: N8N + PostgreSQL
- **dev**: Adds custom node development container
- **admin**: Adds PgAdmin database interface
- **queue**: Adds Redis for queue functionality testing

### Development Settings
The development environment includes:
- Debug logging enabled
- All N8N development features enabled
- Database query logging
- Direct database access
- Hot-reload for custom nodes

### Custom Node Development
The setup automatically:
- Mounts the nodes directory
- Compiles TypeScript in watch mode
- Makes compiled nodes available to N8N
- Provides hot-reload functionality

## 📝 Development Tips

### Workflow Development
1. **Use Version Control**: Export workflows as JSON and commit them
2. **Environment Variables**: Use environment variables for configuration
3. **Error Handling**: Add proper error handling to workflows
4. **Testing**: Test workflows with different data scenarios

### Custom Node Development
1. **Follow Conventions**: Use the provided templates and examples
2. **Add Tests**: Write unit tests for your custom nodes
3. **Documentation**: Document node parameters and functionality
4. **Error Handling**: Implement proper error handling and logging

### Database Development
1. **Backup Data**: Regularly backup your development database
2. **Migration Scripts**: Create migration scripts for schema changes
3. **Performance**: Monitor query performance during development
4. **Indexing**: Add appropriate indexes for better performance

## 🚨 Troubleshooting

### Custom Nodes Not Loading
```bash
# Check compilation errors
docker compose logs n8n-node-dev

# Verify mount points
docker compose exec n8n ls -la /home/node/.n8n/custom/

# Restart N8N
docker compose restart n8n
```

### Database Connection Issues
```bash
# Check PostgreSQL status
docker compose ps postgres

# Test connection
docker compose exec postgres psql -U n8n_dev_user -d n8n_dev -c "SELECT 1;"

# Check logs
docker compose logs postgres
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Reduce logging if needed
# Set N8N_LOG_LEVEL=info in .env

# Check disk space
df -h
```

## 🔄 Resetting Development Environment

### Reset All Data
```bash
docker compose down -v
rm -rf data/
mkdir -p data/{n8n,postgres,redis,pgadmin}
docker compose up -d
```

### Reset Only N8N Data
```bash
docker compose stop n8n
rm -rf data/n8n/
docker compose start n8n
```

### Reset Only Database
```bash
docker compose stop postgres
rm -rf data/postgres/
docker compose start postgres
```

## 📚 Next Steps

1. **Explore Examples**: Check other example configurations
2. **Read Documentation**: Review N8N and custom node documentation
3. **Join Community**: Participate in N8N community discussions
4. **Contribute**: Submit improvements and new features

Happy developing! 🎉
