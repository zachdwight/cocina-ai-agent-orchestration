# Deployment Guide

## Production Deployment

### Prerequisites

- Docker & Docker Compose
- Ruby 3.1+
- PostgreSQL 12+ (instead of SQLite)
- RabbitMQ 3.13+
- Anthropic API key

### Step 1: Environment Configuration

Create `.env.production`:

```bash
# Rails
RAILS_ENV=production
SECRET_KEY_BASE=$(openssl rand -hex 32)
RAILS_LOG_TO_STDOUT=true

# RabbitMQ
RABBITMQ_HOST=rabbitmq.internal
RABBITMQ_PORT=5672
RABBITMQ_USER=cocina_prod
RABBITMQ_PASS=$(openssl rand -base64 24)

# Claude API
ANTHROPIC_API_KEY=sk-ant-xxxxx...
```

### Step 2: Database Setup

Update `web/config/database.yml` for production:

```yaml
production:
  adapter: postgresql
  database: cocina_prod
  username: cocina_user
  password: <%= ENV['DB_PASSWORD'] %>
  host: postgres.internal
  pool: 25
  timeout: 5000
```

### Step 3: Docker Compose for Production

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: cocina_prod
      POSTGRES_USER: cocina_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - cocina-prod

  rabbitmq:
    image: rabbitmq:3.13-management-alpine
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASS}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - cocina-prod

  rails:
    build: ./web
    environment:
      RAILS_ENV: production
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      DATABASE_URL: postgresql://cocina_user:${DB_PASSWORD}@postgres/cocina_prod
      RABBITMQ_HOST: rabbitmq
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
    ports:
      - "3000:3000"
    depends_on:
      - postgres
      - rabbitmq
    networks:
      - cocina-prod

  chef_agent:
    build: ./my_ai_agent_chef
    environment:
      AGENT_ID: chef_prod_001
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      RABBITMQ_HOST: rabbitmq
      MODE: rabbitmq
    depends_on:
      - rabbitmq
    restart: always
    networks:
      - cocina-prod

  sous_agent_1:
    build: ./my_ai_agent_sous
    environment:
      AGENT_ID: sous_prod_001
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      RABBITMQ_HOST: rabbitmq
      MODE: rabbitmq
    depends_on:
      - rabbitmq
    restart: always
    networks:
      - cocina-prod

  sous_agent_2:
    build: ./my_ai_agent_sous
    environment:
      AGENT_ID: sous_prod_002
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      RABBITMQ_HOST: rabbitmq
      MODE: rabbitmq
    depends_on:
      - rabbitmq
    restart: always
    networks:
      - cocina-prod

networks:
  cocina-prod:
    driver: bridge

volumes:
  postgres_data:
  rabbitmq_data:
```

### Step 4: Rails Production Setup

```bash
cd web

# Install dependencies
bundle install --without development test

# Compile assets
bundle exec rails assets:precompile RAILS_ENV=production

# Run migrations
bundle exec rails db:migrate RAILS_ENV=production

# Seed default agents (optional)
bundle exec rails db:seed RAILS_ENV=production
```

### Step 5: Start Services

```bash
docker-compose -f docker-compose.prod.yml up -d

# Check health
docker-compose -f docker-compose.prod.yml ps
docker logs -f <container_name>
```

### Step 6: Configure Web Server

Use Puma or Passenger in production:

```ruby
# web/config/puma.rb
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count
port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }
```

### Step 7: Enable SSL/TLS

```yaml
# docker-compose.prod.yml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./certs:/etc/nginx/certs
    depends_on:
      - rails
```

### Step 8: Monitoring & Logging

```yaml
# Add to docker-compose
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    depends_on:
      - prometheus
```

## Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (GKE, EKS, AKS)
- kubectl configured
- Helm (optional)

### Step 1: Create Docker Images

```bash
docker build -t my-registry/cocina-rails:latest ./web
docker build -t my-registry/cocina-chef:latest ./my_ai_agent_chef
docker build -t my-registry/cocina-sous:latest ./my_ai_agent_sous

docker push my-registry/cocina-*:latest
```

### Step 2: Create Kubernetes Manifests

**rabbitmq-deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3.13-management-alpine
        ports:
        - containerPort: 5672
        - containerPort: 15672
        env:
        - name: RABBITMQ_DEFAULT_USER
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secret
              key: username
        - name: RABBITMQ_DEFAULT_PASS
          valueFrom:
            secretKeyRef:
              name: rabbitmq-secret
              key: password
        volumeMounts:
        - name: rabbitmq-storage
          mountPath: /var/lib/rabbitmq
      volumes:
      - name: rabbitmq-storage
        persistentVolumeClaim:
          claimName: rabbitmq-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
spec:
  selector:
    app: rabbitmq
  ports:
  - name: amqp
    port: 5672
    targetPort: 5672
  - name: management
    port: 15672
    targetPort: 15672
```

**rails-deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cocina-rails
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cocina-rails
  template:
    metadata:
      labels:
        app: cocina-rails
    spec:
      containers:
      - name: rails
        image: my-registry/cocina-rails:latest
        ports:
        - containerPort: 3000
        env:
        - name: RAILS_ENV
          value: "production"
        - name: RABBITMQ_HOST
          value: "rabbitmq"
        - name: ANTHROPIC_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: anthropic_key
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: cocina-rails
spec:
  selector:
    app: cocina-rails
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
```

**agents-deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chef-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chef-agent
  template:
    metadata:
      labels:
        app: chef-agent
    spec:
      containers:
      - name: agent
        image: my-registry/cocina-chef:latest
        env:
        - name: AGENT_ID
          value: "chef_prod_001"
        - name: RABBITMQ_HOST
          value: "rabbitmq"
        - name: MODE
          value: "rabbitmq"
        - name: ANTHROPIC_API_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: anthropic_key
---
# Similar for sous agents
```

### Step 3: Deploy

```bash
# Create secrets
kubectl create secret generic rabbitmq-secret \
  --from-literal=username=cocina \
  --from-literal=password=$(openssl rand -base64 24)

kubectl create secret generic api-keys \
  --from-literal=anthropic_key=sk-ant-...

# Apply manifests
kubectl apply -f rabbitmq-deployment.yaml
kubectl apply -f rails-deployment.yaml
kubectl apply -f agents-deployment.yaml

# Check status
kubectl get pods
kubectl get services
```

## Monitoring

### Key Metrics to Monitor

- **RabbitMQ**: Queue depth, connection count, message rate
- **Rails**: Response time, error rate, active connections
- **Agents**: Task processing time, success rate, uptime
- **Database**: Query time, connection pool usage

### Health Checks

```bash
# Rails health
curl http://localhost:3000/

# RabbitMQ health
curl -u cocina:cocina_pass http://localhost:15672/api/aliveness-test/%2F

# Database
bundle exec rails db:check

# Agent status
docker logs agent_name
```

## Backup & Recovery

### Database Backup

```bash
# PostgreSQL
pg_dump cocina_prod > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore
psql cocina_prod < backup_20260407_120000.sql
```

### RabbitMQ Backup

```bash
# Export definitions
rabbitmqctl export_definitions definitions.json

# Import
rabbitmqctl import_definitions definitions.json
```

### Restore from Backup

```bash
# Stop services
docker-compose down

# Restore databases
psql cocina_prod < backup.sql

# Restart
docker-compose up -d
```

## Scaling

### Horizontal Scaling

Add more agent instances:

```yaml
sous_agent_3:
  build: ./my_ai_agent_sous
  environment:
    AGENT_ID: sous_prod_003
    # ... same as others
```

### Vertical Scaling

Update resource limits:

```yaml
rails:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '1'
        memory: 1G
```

## Troubleshooting Production Issues

### Rails not starting

```bash
# Check logs
docker logs cocina-rails

# Manual migration
docker exec cocina-rails bundle exec rails db:migrate RAILS_ENV=production

# Check secrets
docker exec cocina-rails printenv | grep ANTHROPIC
```

### Agents not receiving messages

```bash
# Check RabbitMQ connection
docker exec rabbitmq rabbitmqctl list_connections

# Check queue status
docker exec rabbitmq rabbitmqctl list_queues

# Restart agents
docker restart chef_agent sous_agent_1 sous_agent_2
```

### Database connection issues

```bash
# Check connectivity
docker exec rails bundle exec rails db:check

# Check migrations
docker exec rails bundle exec rails db:migrate:status

# Reset (careful!)
docker exec rails bundle exec rails db:drop db:create db:migrate
```

## Security Best Practices

1. **Secrets Management**: Use environment-specific `.env` files (not in git)
2. **API Keys**: Rotate Anthropic API key monthly
3. **Network**: Use private networks for inter-service communication
4. **Firewall**: Restrict RabbitMQ port 5672 to authorized services only
5. **SSL/TLS**: Enable encryption for all network traffic
6. **Logging**: Log all agent actions for audit trail
7. **Authentication**: Implement Rails authentication for UI access

## Disaster Recovery Plan

- **RTO** (Recovery Time Objective): < 1 hour
- **RPO** (Recovery Point Objective): < 15 minutes

Steps:
1. Backup all data every 15 minutes
2. Test restore process weekly
3. Maintain 2-week backup history
4. Document recovery procedures
5. Train team on recovery process
