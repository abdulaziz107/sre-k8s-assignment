# System Architecture Documentation

## Overview

This SRE assignment implements a microservices architecture with three main services, external dependencies, and comprehensive monitoring. The system is designed for reliability, security, observability, and scalability.

## Architecture Components

### 1. Microservices

#### Auth Service (Node.js)
- **Purpose**: Authentication and authorization
- **Port**: 3001
- **Database**: PostgreSQL (auth_db)
- **Endpoints**:
  - `POST /register` - User registration
  - `POST /login` - User authentication
  - `POST /verify` - Token verification
  - `GET /health` - Health check
  - `GET /metrics` - Prometheus metrics

#### API Service (Go)
- **Purpose**: Main API gateway and business logic
- **Port**: 3002
- **Database**: PostgreSQL (api_db)
- **Dependencies**: Auth Service for token verification
- **Endpoints**:
  - `GET /api/v1/posts` - Public posts
  - `POST /api/v1/posts` - Create post (authenticated)
  - `GET /api/v1/posts/my` - User's posts (authenticated)
  - `DELETE /api/v1/posts/:id` - Delete post (authenticated)
  - `GET /health` - Health check
  - `GET /metrics` - Prometheus metrics

#### Image Storage Service (Python)
- **Purpose**: Image upload, storage, and retrieval
- **Port**: 3003
- **Database**: PostgreSQL (image_db)
- **Storage**: MinIO object storage
- **Endpoints**:
  - `POST /upload` - Upload image (authenticated)
  - `GET /images` - List user's images (authenticated)
  - `GET /images/:filename` - Download image (authenticated)
  - `DELETE /images/:filename` - Delete image (authenticated)
  - `GET /stats` - Storage statistics (authenticated)
  - `GET /health` - Health check
  - `GET /metrics` - Prometheus metrics

### 2. Infrastructure Components

#### PostgreSQL Database
- **Purpose**: Primary data storage
- **Port**: 5432
- **Databases**:
  - `auth_db` - User authentication data
  - `api_db` - Application data (posts, etc.)
  - `image_db` - Image metadata
- **Users**:
  - `auth_user` - Auth service access
  - `api_user` - API service access
  - `image_user` - Image service access

#### MinIO Object Storage
- **Purpose**: Image file storage
- **Ports**: 9000 (API), 9001 (Console)
- **Bucket**: `images`
- **Access**: Via MinIO client in image service

### 3. Security Components

#### Network Policies
- **Auth Service**: Accepts connections from API service and monitoring
- **API Service**: Accepts external traffic and connects to auth service
- **Image Service**: Accepts connections from API service and monitoring
- **Infrastructure**: Restricted access from services only

#### Secrets Management
- **JWT Secrets**: Shared across services for token validation
- **Database Passwords**: Service-specific database credentials
- **MinIO Credentials**: Access keys for object storage

#### TLS/SSL
- **Ingress**: TLS termination with Let's Encrypt certificates
- **Internal**: Service-to-service communication within cluster

### 4. Monitoring Stack

#### Prometheus
- **Purpose**: Metrics collection and alerting
- **Targets**: All services and infrastructure components
- **Scraping**: 15-second intervals
- **Alerts**: High error rates, service unavailability, resource usage

#### Grafana
- **Purpose**: Metrics visualization and dashboards
- **Dashboards**:
  - Global overview
  - Service-specific dashboards
  - Infrastructure monitoring

#### Alertmanager
- **Purpose**: Alert routing and notification
- **Integrations**: Slack, email, etc.

### 5. Autoscaling

#### Horizontal Pod Autoscaler (HPA)
- **Auth Service**: 2-10 replicas, CPU/Memory based
- **API Service**: 2-15 replicas, CPU/Memory based
- **Image Service**: 2-20 replicas, CPU/Memory based

#### Pod Disruption Budgets (PDB)
- **Minimum Availability**: 1 replica per service
- **Purpose**: Ensure availability during node drains

## Communication Flow

### 1. User Authentication Flow
```
Client → Ingress → API Service → Auth Service → Database
                ↓
            Response with JWT
```

### 2. API Request Flow
```
Client → Ingress → API Service → Auth Service (token validation)
                ↓
            Business Logic → Database
                ↓
            Response
```

### 3. Image Upload Flow
```
Client → Ingress → API Service → Image Service → MinIO + Database
                ↓
            Response with image metadata
```

### 4. Monitoring Flow
```
Services → Prometheus → Grafana
                ↓
            Alertmanager → Notifications
```

## Security Architecture

### Network Isolation
- **Namespaces**: Separate namespaces for each service
- **Network Policies**: Explicit allow rules for service communication
- **Pod Security**: Non-root containers, read-only filesystems

### Authentication & Authorization
- **JWT Tokens**: Stateless authentication
- **Service-to-Service**: Internal service communication
- **External Access**: Through ingress with TLS

### Data Protection
- **Secrets**: Kubernetes secrets for sensitive data
- **Encryption**: TLS for all external communication
- **Access Control**: Database user isolation

## Scalability Features

### Horizontal Scaling
- **HPA**: Automatic scaling based on metrics
- **Load Balancing**: Kubernetes service load balancing
- **Stateless Services**: Easy horizontal scaling

### Resource Management
- **Resource Limits**: CPU and memory limits per container
- **Resource Requests**: Guaranteed resources for pods
- **Quality of Service**: Burstable QoS class

### High Availability
- **Multi-replica Deployments**: Redundancy
- **Pod Disruption Budgets**: Availability guarantees
- **Health Checks**: Liveness and readiness probes

## Observability Features

### Metrics
- **Application Metrics**: Custom business metrics
- **Infrastructure Metrics**: CPU, memory, network
- **Service Metrics**: Request rates, error rates, latency

### Logging
- **Structured Logging**: JSON format logs
- **Centralized Logging**: Kubernetes logging
- **Log Aggregation**: Via monitoring stack

### Tracing
- **Distributed Tracing**: Request tracing across services
- **Performance Monitoring**: Latency analysis
- **Error Tracking**: Error correlation

## Disaster Recovery

### Backup Strategy
- **Database Backups**: PostgreSQL backups
- **Object Storage**: MinIO data replication
- **Configuration**: Git-based configuration management

### Recovery Procedures
- **Service Recovery**: Automatic pod rescheduling
- **Data Recovery**: Database and storage recovery
- **Rollback Procedures**: Deployment rollbacks

## Performance Characteristics

### Latency
- **Service-to-Service**: < 10ms
- **Database Queries**: < 50ms
- **Image Upload**: < 5s for 10MB images

### Throughput
- **API Requests**: 1000+ requests/second
- **Image Uploads**: 100+ concurrent uploads
- **Database Connections**: Connection pooling

### Resource Usage
- **Memory**: 128-512MB per service
- **CPU**: 100-400m per service
- **Storage**: Variable based on image storage

## Deployment Architecture

### Namespace Organization
```
├── auth/                 # Authentication service
├── api/                  # API gateway service
├── image-storage/        # Image storage service
├── infrastructure/       # Database and storage
├── monitoring/           # Observability stack
└── ingress-nginx/        # Ingress controller
```

### Service Dependencies
```
API Service → Auth Service → Database
API Service → Image Service → Database + MinIO
Monitoring → All Services
```

This architecture provides a robust, scalable, and observable system that demonstrates SRE best practices including reliability, security, and operational excellence. 