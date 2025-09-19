# N8N-R8 System Architecture Overview

This document provides a comprehensive overview of the N8N-R8 system architecture, including all components, their relationships, and deployment options.

## High-Level Architecture

```mermaid
graph TB
    subgraph "External Access"
        U[Users] --> LB[Load Balancer/Proxy]
        API[External APIs] --> N8N
    end
    
    subgraph "Proxy Layer"
        LB --> NGINX[Nginx Proxy]
        LB --> TRAEFIK[Traefik Proxy]
    end
    
    subgraph "Application Layer"
        NGINX --> N8N[N8N Workflow Engine]
        TRAEFIK --> N8N
        N8N --> CN[Custom Nodes]
    end
    
    subgraph "Data Layer"
        N8N --> PG[PostgreSQL Database]
        N8N --> REDIS[Redis Cache/Queue]
        N8N --> FS[File Storage]
    end
    
    subgraph "Monitoring Layer"
        PROM[Prometheus] --> N8N
        PROM --> PG
        PROM --> REDIS
        PROM --> NGINX
        PROM --> TRAEFIK
        GRAF[Grafana] --> PROM
        AM[Alertmanager] --> PROM
        LOKI[Loki] --> LOGS[Application Logs]
    end
    
    subgraph "Backup System"
        BACKUP[Backup Service] --> PG
        BACKUP --> REDIS
        BACKUP --> FS
        BACKUP --> BS[Backup Storage]
    end
    
    style N8N fill:#e1f5fe
    style PG fill:#f3e5f5
    style REDIS fill:#fff3e0
    style NGINX fill:#e8f5e8
    style TRAEFIK fill:#fff8e1
    style PROM fill:#fce4ec
    style GRAF fill:#f1f8e9
```

## Component Overview

### Core Components

| Component | Purpose | Technology | Port(s) |
|-----------|---------|------------|---------|
| **N8N** | Workflow automation engine | Node.js | 5678 |
| **PostgreSQL** | Primary database | PostgreSQL 15+ | 5432 |
| **Redis** | Cache and queue management | Redis 7+ | 6379 |

### Proxy Components

| Component | Purpose | Technology | Port(s) |
|-----------|---------|------------|---------|
| **Nginx** | Reverse proxy, SSL termination | Nginx | 80, 443 |
| **Traefik** | Dynamic reverse proxy, auto-SSL | Traefik v3 | 80, 443, 8080 |

### Monitoring Components

| Component | Purpose | Technology | Port(s) |
|-----------|---------|------------|---------|
| **Prometheus** | Metrics collection | Prometheus | 9090 |
| **Grafana** | Metrics visualization | Grafana | 3000 |
| **Alertmanager** | Alert management | Alertmanager | 9093 |
| **Loki** | Log aggregation | Loki | 3100 |
| **Promtail** | Log shipping | Promtail | 9080 |
| **cAdvisor** | Container metrics | cAdvisor | 8080 |
| **Node Exporter** | System metrics | Node Exporter | 9100 |

## Deployment Architectures

### 1. Development Architecture

```mermaid
graph LR
    subgraph "Development Environment"
        DEV[Developer] --> N8N[N8N:5678]
        N8N --> PG[PostgreSQL]
        N8N --> REDIS[Redis]
        N8N --> FS[Local Files]
    end
    
    style N8N fill:#e1f5fe
    style PG fill:#f3e5f5
    style REDIS fill:#fff3e0
```

**Characteristics:**
- Direct access to N8N on port 5678
- Minimal security configuration
- Local file storage
- Basic monitoring (optional)

### 2. Production with Nginx

```mermaid
graph TB
    subgraph "Internet"
        USERS[Users] --> DNS[Domain Name]
    end
    
    subgraph "Production Environment"
        DNS --> NGINX[Nginx Proxy:80/443]
        NGINX --> N8N[N8N:5678]
        
        subgraph "Data Services"
            N8N --> PG[PostgreSQL:5432]
            N8N --> REDIS[Redis:6379]
        end
        
        subgraph "Monitoring Stack"
            PROM[Prometheus:9090] --> N8N
            GRAF[Grafana:3000] --> PROM
            AM[Alertmanager:9093] --> PROM
        end
        
        subgraph "Storage"
            N8N --> VOL[Docker Volumes]
            PG --> VOL
            REDIS --> VOL
        end
    end
    
    style NGINX fill:#e8f5e8
    style N8N fill:#e1f5fe
    style PG fill:#f3e5f5
    style REDIS fill:#fff3e0
    style PROM fill:#fce4ec
    style GRAF fill:#f1f8e9
```

**Characteristics:**
- SSL/TLS termination at Nginx
- Static configuration
- Manual certificate management
- Production-ready security headers

### 3. Production with Traefik

```mermaid
graph TB
    subgraph "Internet"
        USERS[Users] --> DNS[Domain Name]
    end
    
    subgraph "Production Environment"
        DNS --> TRAEFIK[Traefik Proxy:80/443]
        TRAEFIK --> N8N[N8N:5678]
        
        subgraph "Auto-Discovery"
            TRAEFIK --> DOCKER[Docker API]
            TRAEFIK --> ACME[Let's Encrypt]
        end
        
        subgraph "Data Services"
            N8N --> PG[PostgreSQL:5432]
            N8N --> REDIS[Redis:6379]
        end
        
        subgraph "Monitoring Stack"
            PROM[Prometheus:9090] --> N8N
            GRAF[Grafana:3000] --> PROM
            TRAEFIK --> DASH[Dashboard:8080]
        end
    end
    
    style TRAEFIK fill:#fff8e1
    style N8N fill:#e1f5fe
    style PG fill:#f3e5f5
    style REDIS fill:#fff3e0
    style PROM fill:#fce4ec
    style GRAF fill:#f1f8e9
```

**Characteristics:**
- Automatic SSL certificate management
- Dynamic service discovery
- Built-in dashboard
- Advanced routing capabilities

## Data Flow Architecture

### 1. Workflow Execution Flow

```mermaid
sequenceDiagram
    participant U as User
    participant N as N8N Engine
    participant PG as PostgreSQL
    participant R as Redis
    participant API as External API
    
    U->>N: Trigger Workflow
    N->>PG: Load Workflow Definition
    N->>R: Queue Execution
    N->>R: Get Execution State
    N->>API: Execute Node Action
    API-->>N: Return Response
    N->>PG: Save Execution Result
    N->>R: Update Queue Status
    N-->>U: Return Result
```

### 2. Authentication Flow

```mermaid
sequenceDiagram
    participant U as User
    participant P as Proxy
    participant N as N8N
    participant PG as PostgreSQL
    
    U->>P: Login Request
    P->>N: Forward Request
    N->>PG: Validate Credentials
    PG-->>N: User Data
    N-->>P: JWT Token
    P-->>U: Set Cookie/Token
    
    Note over U,PG: Subsequent Requests
    U->>P: API Request + Token
    P->>N: Forward with Token
    N->>N: Validate JWT
    N-->>P: Response
    P-->>U: Response
```

### 3. Monitoring Data Flow

```mermaid
graph LR
    subgraph "Application Layer"
        N8N[N8N] --> M1[Metrics Endpoint]
        PG[PostgreSQL] --> M2[DB Metrics]
        REDIS[Redis] --> M3[Cache Metrics]
        NGINX[Nginx] --> M4[Proxy Metrics]
    end
    
    subgraph "Collection Layer"
        M1 --> PROM[Prometheus]
        M2 --> PROM
        M3 --> PROM
        M4 --> PROM
        CADV[cAdvisor] --> PROM
        NODE[Node Exporter] --> PROM
    end
    
    subgraph "Storage & Visualization"
        PROM --> GRAF[Grafana]
        PROM --> AM[Alertmanager]
        AM --> EMAIL[Email Alerts]
        AM --> SLACK[Slack Alerts]
    end
    
    subgraph "Log Pipeline"
        N8N --> LOGS[Application Logs]
        LOGS --> LOKI[Loki]
        LOKI --> GRAF
    end
```

## Network Architecture

### Container Network Topology

```mermaid
graph TB
    subgraph "Docker Host"
        subgraph "n8n-network (Bridge)"
            N8N[n8n:5678]
            PG[postgres:5432]
            REDIS[redis:6379]
            NGINX[nginx:80/443]
            TRAEFIK[traefik:80/443/8080]
        end
        
        subgraph "monitoring-network (Bridge)"
            PROM[prometheus:9090]
            GRAF[grafana:3000]
            AM[alertmanager:9093]
            LOKI[loki:3100]
        end
        
        subgraph "Host Network"
            HOST[Host:22,80,443]
        end
    end
    
    subgraph "External"
        INTERNET[Internet]
        DNS[DNS Servers]
    end
    
    INTERNET --> HOST
    HOST --> NGINX
    HOST --> TRAEFIK
    N8N -.-> PG
    N8N -.-> REDIS
    NGINX -.-> N8N
    TRAEFIK -.-> N8N
    PROM -.-> N8N
    GRAF -.-> PROM
```

### Port Mapping Strategy

| Service | Internal Port | External Port | Protocol | Purpose |
|---------|---------------|---------------|----------|---------|
| N8N | 5678 | 5678* | HTTP | Direct access (dev only) |
| PostgreSQL | 5432 | - | TCP | Internal database |
| Redis | 6379 | - | TCP | Internal cache |
| Nginx | 80/443 | 80/443 | HTTP/HTTPS | Web proxy |
| Traefik | 80/443/8080 | 80/443/8080 | HTTP/HTTPS | Web proxy + dashboard |
| Prometheus | 9090 | 9090* | HTTP | Metrics collection |
| Grafana | 3000 | 3000* | HTTP | Dashboards |
| Alertmanager | 9093 | 9093* | HTTP | Alert management |

*Exposed only when monitoring is enabled

## Security Architecture

### Security Layers

```mermaid
graph TB
    subgraph "External Security"
        FW[Firewall] --> WAF[Web Application Firewall]
        WAF --> DDOS[DDoS Protection]
    end
    
    subgraph "Proxy Security"
        DDOS --> SSL[SSL/TLS Termination]
        SSL --> AUTH[Authentication]
        AUTH --> HEADERS[Security Headers]
    end
    
    subgraph "Application Security"
        HEADERS --> N8N[N8N Application]
        N8N --> RBAC[Role-Based Access]
        N8N --> ENCRYPT[Data Encryption]
    end
    
    subgraph "Data Security"
        ENCRYPT --> PG[Encrypted Database]
        ENCRYPT --> REDIS[Secured Cache]
        ENCRYPT --> FS[Encrypted Storage]
    end
    
    subgraph "Network Security"
        N8N -.-> NETWORK[Internal Networks]
        NETWORK -.-> ISOLATION[Container Isolation]
        ISOLATION -.-> SECRETS[Secret Management]
    end
```

### Authentication & Authorization

```mermaid
graph LR
    subgraph "Authentication Methods"
        BASIC[Basic Auth] --> N8N
        LDAP[LDAP/AD] --> N8N
        OAUTH[OAuth 2.0] --> N8N
        SAML[SAML SSO] --> N8N
    end
    
    subgraph "Authorization Levels"
        N8N --> ADMIN[Admin Access]
        N8N --> USER[User Access]
        N8N --> READONLY[Read-Only Access]
        N8N --> API[API Access]
    end
    
    subgraph "Resource Protection"
        ADMIN --> WORKFLOWS[Workflow Management]
        USER --> EXECUTE[Workflow Execution]
        READONLY --> VIEW[View Only]
        API --> EXTERNAL[External Integration]
    end
```

## Scalability Considerations

### Horizontal Scaling Options

```mermaid
graph TB
    subgraph "Load Balancer"
        LB[Load Balancer]
    end
    
    subgraph "N8N Instances"
        LB --> N8N1[N8N Instance 1]
        LB --> N8N2[N8N Instance 2]
        LB --> N8N3[N8N Instance 3]
    end
    
    subgraph "Shared Services"
        N8N1 --> PG[PostgreSQL Cluster]
        N8N2 --> PG
        N8N3 --> PG
        N8N1 --> REDIS[Redis Cluster]
        N8N2 --> REDIS
        N8N3 --> REDIS
    end
    
    subgraph "Storage"
        PG --> STORAGE[Shared Storage]
        REDIS --> STORAGE
    end
```

### Performance Optimization Points

1. **Database Optimization**
   - Connection pooling
   - Query optimization
   - Index management
   - Read replicas

2. **Cache Strategy**
   - Redis clustering
   - Cache warming
   - TTL optimization
   - Memory management

3. **Application Scaling**
   - Worker processes
   - Queue management
   - Resource allocation
   - Load balancing

4. **Storage Optimization**
   - SSD storage
   - Volume optimization
   - Backup strategies
   - Cleanup policies

## Technology Stack

### Core Technologies

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Runtime** | Node.js | 18+ | Application runtime |
| **Framework** | N8N | Latest | Workflow engine |
| **Database** | PostgreSQL | 15+ | Primary data store |
| **Cache** | Redis | 7+ | Caching and queues |
| **Containerization** | Docker | 20.10+ | Application packaging |
| **Orchestration** | Docker Compose | 2.0+ | Service orchestration |

### Infrastructure Technologies

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| **Proxy** | Nginx | 1.24+ | Reverse proxy |
| **Proxy** | Traefik | 3.0+ | Dynamic proxy |
| **Monitoring** | Prometheus | Latest | Metrics collection |
| **Visualization** | Grafana | Latest | Dashboards |
| **Logging** | Loki | Latest | Log aggregation |
| **Alerting** | Alertmanager | Latest | Alert management |

## Next Steps

- [Component Details](components.md) - Detailed component descriptions
- [Network Architecture](networking.md) - Network design and security
- [Data Flow](data-flow.md) - Detailed data flow diagrams
- [Deployment Guide](../deployment/production.md) - Production deployment
- [Monitoring Setup](../monitoring/setup.md) - Monitoring configuration
