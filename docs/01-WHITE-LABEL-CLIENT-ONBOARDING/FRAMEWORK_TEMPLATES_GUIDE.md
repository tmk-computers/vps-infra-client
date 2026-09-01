# 📦 VPS-Infra: Multi-Framework Templates & Deployment Guide

VPS-Infra provides enterprise-grade, production-hardened Docker Compose and Dockerfile templates for modern backend and frontend web frameworks with automated **Traefik SSL certificates**, multi-database connectivity, and isolated persistent volumes.

---

## 🏛️ Supported Technology Matrix

| Framework Category | Technology Stack | Default Container Port | Multi-Stage Dockerfile |
|---|---|---|---|
| **Backend API** | **Spring Boot** (Java 21 / 17) | `8080` | `Dockerfile.spring-boot` |
| **Backend API / Web** | **Laravel** (PHP 8.3 / 8.2) | `80` | `Dockerfile.laravel` |
| **Backend API / AI** | **FastAPI** (Python 3.12 / 3.11) | `8000` | `Dockerfile.fastapi` |
| **Backend API** | **.NET 10 / 8 Web API** (C#) | `8080` | `Dockerfile.dotnet` |
| **Backend API** | **Express.js** (Node 20 / 22) | `3000` | `Dockerfile.express` |
| **Frontend Web** | **React** (Vite / TypeScript / CRA) | `80` | `Dockerfile.react` |
| **Frontend Web** | **Angular** (Angular 18 / 19) | `80` | `Dockerfile.angular` |

---

## ☕ 1. Spring Boot (Java 21 / 17)

### 📄 Docker Compose Template (`templates/docker-compose.spring-boot.template.yml`):
```yaml
services:
  order-api-prod:
    image: localhost:5000/tmk/order-api:latest
    container_name: order-api-prod
    restart: always
    environment:
      - SPRING_PROFILES_ACTIVE=production
      - SERVER_PORT=8080
      # PostgreSQL Database:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://shared_postgres:5432/order_api_prod?reWriteBatchedInserts=true
      - SPRING_DATASOURCE_USERNAME=postgres
      - SPRING_DATASOURCE_PASSWORD=StrongPostgres@123
      - SPRING_JPA_HIBERNATE_DDL_AUTO=update
      # JVM Container Performance:
      - JAVA_OPTS=-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC
    volumes:
      - /var/www/vps-infra/volumes/apps/order-api/prod/uploads:/app/uploads
      - /var/www/vps-infra/volumes/apps/order-api/prod/logs:/app/logs
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.order-api-prod.rule=Host(`api.orders.example.com`)"
      - "traefik.http.routers.order-api-prod.entrypoints=websecure"
      - "traefik.http.routers.order-api-prod.tls=true"
      - "traefik.http.routers.order-api-prod.tls.certresolver=myresolver"
      - "traefik.http.services.order-api-prod.loadbalancer.server.port=8080"
```

---

## 🐘 2. Laravel (PHP 8.3 / 8.2)

### 📄 Docker Compose Template (`templates/docker-compose.laravel.template.yml`):
```yaml
services:
  billing-portal-prod:
    image: localhost:5000/tmk/billing-portal:latest
    container_name: billing-portal-prod
    restart: always
    environment:
      - APP_ENV=production
      - APP_DEBUG=false
      - APP_URL=https://billing.example.com
      - DB_CONNECTION=pgsql
      - DB_HOST=shared_postgres
      - DB_PORT=5432
      - DB_DATABASE=billing_prod
      - DB_USERNAME=postgres
      - DB_PASSWORD=StrongPostgres@123
    volumes:
      - /var/www/vps-infra/volumes/apps/billing-portal/prod/storage:/var/www/html/storage
      - /var/www/vps-infra/volumes/apps/billing-portal/prod/uploads:/var/www/html/public/uploads
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.billing-portal-prod.rule=Host(`billing.example.com`)"
      - "traefik.http.routers.billing-portal-prod.entrypoints=websecure"
      - "traefik.http.routers.billing-portal-prod.tls=true"
      - "traefik.http.routers.billing-portal-prod.tls.certresolver=myresolver"
      - "traefik.http.services.billing-portal-prod.loadbalancer.server.port=80"
```

---

## ⚡ 3. FastAPI (Python 3.12)

### 📄 Docker Compose Template (`templates/docker-compose.fastapi.template.yml`):
```yaml
services:
  ai-service-prod:
    image: localhost:5000/tmk/ai-service:latest
    container_name: ai-service-prod
    restart: always
    environment:
      - ENVIRONMENT=production
      - PORT=8000
      - WORKERS=4
      - DATABASE_URL=postgresql://postgres:StrongPostgres@123@shared_postgres:5432/ai_prod
    volumes:
      - /var/www/vps-infra/volumes/apps/ai-service/prod/uploads:/app/uploads
      - /var/www/vps-infra/volumes/apps/ai-service/prod/models:/app/models
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ai-service-prod.rule=Host(`ai.example.com`)"
      - "traefik.http.routers.ai-service-prod.entrypoints=websecure"
      - "traefik.http.routers.ai-service-prod.tls=true"
      - "traefik.http.routers.ai-service-prod.tls.certresolver=myresolver"
      - "traefik.http.services.ai-service-prod.loadbalancer.server.port=8000"
```

---

## ⚛️ 4. React (Vite / TypeScript / Tailwind)

### 📄 Docker Compose Template (`templates/docker-compose.react-web.template.yml`):
```yaml
services:
  customer-web-prod:
    image: localhost:5000/tmk/customer-web:latest
    container_name: customer-web-prod
    restart: always
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.customer-web-prod.rule=Host(`app.example.com`)"
      - "traefik.http.routers.customer-web-prod.entrypoints=websecure"
      - "traefik.http.routers.customer-web-prod.tls=true"
      - "traefik.http.routers.customer-web-prod.tls.certresolver=myresolver"
      - "traefik.http.services.customer-web-prod.loadbalancer.server.port=80"
```

---

## 🅰️ 5. Angular (Angular 18 / 19)

### 📄 Docker Compose Template (`templates/docker-compose.angular-web.template.yml`):
```yaml
services:
  admin-angular-prod:
    image: localhost:5000/tmk/admin-angular:latest
    container_name: admin-angular-prod
    restart: always
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.admin-angular-prod.rule=Host(`admin.example.com`)"
      - "traefik.http.routers.admin-angular-prod.entrypoints=websecure"
      - "traefik.http.routers.admin-angular-prod.tls=true"
      - "traefik.http.routers.admin-angular-prod.tls.certresolver=myresolver"
      - "traefik.http.services.admin-angular-prod.loadbalancer.server.port=80"
```

---

## 💾 Multi-Database Connection String Cheatsheet

Connect your microservices seamlessly using the shared cluster hostnames:

| Engine | Hostname | Port | Credentials | Connection String Sample |
|---|---|---|---|---|
| **PostgreSQL** | `shared_postgres` | `5432` | `postgres` / `StrongPostgres@123` | `Host=shared_postgres;Port=5432;Database=mydb;Username=postgres;Password=StrongPostgres@123;` |
| **MariaDB / MySQL** | `shared_mariadb` | `3306` | `root` / `StrongMariaDB@123` | `Server=shared_mariadb;Port=3306;Database=mydb;Uid=root;Pwd=StrongMariaDB@123;` |
| **MongoDB** | `shared_mongodb` | `27017` | `root` / `StrongMongo@123` | `mongodb://root:StrongMongo@123@shared_mongodb:27017/mydb?authSource=admin` |
| **MS SQL Server** | `shared_sqlserver` | `1433` | `sa` / `StrongSQLServer@123` | `Server=shared_sqlserver,1433;Database=mydb;User Id=sa;Password=StrongSQLServer@123;TrustServerCertificate=True;` |
| **Oracle 23ai** | `shared_oracle` | `1521` | `system` / `StrongOracle@123` | `Data Source=shared_oracle:1521/FREEPDB1;User Id=system;Password=StrongOracle@123;` |
