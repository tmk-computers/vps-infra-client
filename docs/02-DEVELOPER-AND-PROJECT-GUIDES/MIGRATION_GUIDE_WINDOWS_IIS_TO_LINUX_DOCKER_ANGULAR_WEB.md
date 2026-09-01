# Complete Migration Guide: Windows IIS Native Angular Web Application to Linux Docker Platform (VPS-Infra)

## Executive Summary & Architecture Overview

This migration guide details the process of migrating client-facing **Angular Single Page Applications (SPAs)** from legacy **Windows IIS web servers** to containerized **Linux Nginx Docker** environments running on the **VPS-Infra** platform.

```
+-----------------------------------------------------------------------------------------+
|                                    VPS-INFRA PLATFORM                                   |
|                                                                                         |
|  +-----------------------------------------------------------------------------------+  |
|  |                   TRAEFIK REVERSE PROXY (SSL / Host Routing)                      |  |
|  |     https://bankmitra.tmkcomputers.in       |  https://uat-bankmitra.tmkcomputers |  |
|  +---------------------------------------------+-------------------------------------+  |
|                        |                                           |                    |
|                        v (traefik_net)                             v (traefik_net)      |
|  +------------------------------------------+  +-------------------------------------+  |
|  |       bank-mitra-web-prod (Port 80)      |  |       bank-mitra-web-uat (Port 80)  |  |
|  |       Nginx 1.27 Alpine Static Server    |  |       Nginx 1.27 Alpine Static Srv  |  |
|  +---------------------+--------------------+  +-------------------+-----------------+  |
|                        |                                           |                    |
|                        v (Browser HTTP/2 API calls)                v (Browser API calls)|
|  +------------------------------------------+  +-------------------------------------+  |
|  |    https://bankmitra-api.tmkcomputers.in |  |  https://uat-bankmitra-api...       |  |
|  +------------------------------------------+  +-------------------------------------+  |
+-----------------------------------------------------------------------------------------+
```

---

## 1. Key Architectural Differences: Windows IIS vs Linux Nginx Docker

| Feature / Behavior | Windows IIS Native (`web.config`) | Linux Nginx Docker (`nginx.conf`) |
| :--- | :--- | :--- |
| **Routing / Deep Linking** | IIS URL Rewrite Module with rewrite rules in `web.config` | Native Nginx `try_files $uri $uri/ /index.html;` |
| **Filesystem Case Sensitivity** | Case-insensitive (`/Logs` and `/logs` resolve identically) | Case-sensitive (`import './Logs/...'` fails if path casing does not match disk) |
| **Static File Serving** | Windows Static File Handler | High-throughput asynchronous event-driven Nginx engine |
| **Environment Configuration** | Often manually modified `dist/` or separate IIS sites | `ARG CONFIGURATION={production\|uat}` baked during multi-stage Docker build |
| **Gzip & Brotli Compression** | IIS Dynamic Compression module | Nginx `gzip on; gzip_types ...;` |
| **SSL / TLS Management** | Bound to IIS site via Windows Certificate Store / win-acme | Traefik Reverse Proxy with automated Let's Encrypt certificates |
| **Container Footprint** | N/A (Windows OS dependency) | Lean lightweight Alpine image (~25MB runtime) |

---

## 2. Step-by-Step Migration Process

### Step 1: Source Code Audit & Linux Case Sensitivity Fixes

Windows NTFS file systems are case-insensitive. When compiling TypeScript/Angular on Linux, case mismatches in route imports immediately cause compilation errors (`TS2307: Cannot find module`).

1. **Verify Route and Component Paths**:
   Ensure route files match on-disk folder casing exactly:
   ```typescript
   // WRONG (Fails on Linux if directory on disk is 'Logs'):
   import('./main_pages/logs/logs.route')

   // CORRECT:
   import('./main_pages/Logs/logs.route')
   ```

2. **Verify Asset References**:
   Ensure `assets/` and `public/` files in templates (`src/assets/images/...`) match disk casing.

---

### Step 2: Environment-Specific API Endpoints

Configure distinct environment files for each deployment target.

#### `src/environments/environment.prod.ts`
```typescript
export const environment = {
    production: true,
    apiBaseUrl: 'https://bankmitra-api.tmkcomputers.in/'
};
```

#### `src/environments/environment.uat.ts`
```typescript
export const environment = {
    production: true,
    apiBaseUrl: 'https://uat-bankmitra-api.tmkcomputers.in/'
};
```

In `angular.json`, ensure `fileReplacements` maps each configuration:
```json
"configurations": {
  "production": {
    "fileReplacements": [
      {
        "replace": "src/environments/environment.ts",
        "with": "src/environments/environment.prod.ts"
      }
    ]
  },
  "uat": {
    "fileReplacements": [
      {
        "replace": "src/environments/environment.ts",
        "with": "src/environments/environment.uat.ts"
      }
    ]
  }
}
```

---

### Step 3: Production Nginx Configuration (`nginx.conf`)

Replace the IIS `web.config` URL Rewrite rules with a hardened `nginx.conf`:

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Enable Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/javascript application/json image/svg+xml;
    gzip_disable "MSIE [1-6]\.";

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # SPA Deep Linking Fallback
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Static Asset Caching
    location ~* \.(?:ico|css|js|gif|jpe?g|png|woff2?|eot|ttf|svg)$ {
        expires 6M;
        access_log off;
        add_header Cache-Control "public, max-age=15552000, immutable";
    }
}
```

---

### Step 4: Multi-Stage Dockerfile

Create a multi-stage `Dockerfile` with build arguments for environment targets:

```dockerfile
# ------------------------------
# 1) Build stage
# ------------------------------
FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci --legacy-peer-deps || npm install --legacy-peer-deps

COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"
ARG CONFIGURATION=production
RUN npm run build -- --configuration $CONFIGURATION

# ------------------------------
# 2) Runtime stage (Nginx Alpine)
# ------------------------------
FROM nginx:stable-alpine

# Copy built browser assets from Angular output directory
COPY --from=build /app/dist/approx-ng/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

### Step 5: Docker Compose & Traefik Routing

Create `docker-compose.yml` to run Production and UAT side-by-side with automated Let's Encrypt SSL certificates:

```yaml
services:
  bank-mitra-web-prod:
    build:
      context: .
      args:
        CONFIGURATION: production
    image: localhost:5000/bank-mitra-web:${IMAGE_TAG:-prod}
    container_name: bank-mitra-web-prod
    restart: always
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bank-mitra-web-prod-http.rule=Host(`bankmitra.tmkcomputers.in`)"
      - "traefik.http.routers.bank-mitra-web-prod-http.entrypoints=web"
      - "traefik.http.routers.bank-mitra-web-prod.rule=Host(`bankmitra.tmkcomputers.in`)"
      - "traefik.http.routers.bank-mitra-web-prod.entrypoints=websecure"
      - "traefik.http.routers.bank-mitra-web-prod.tls=true"
      - "traefik.http.routers.bank-mitra-web-prod.tls.certresolver=myresolver"
      - "traefik.http.services.bank-mitra-web-prod.loadbalancer.server.port=80"

  bank-mitra-web-uat:
    build:
      context: .
      args:
        CONFIGURATION: uat
    image: localhost:5000/bank-mitra-web:${IMAGE_TAG:-uat}
    container_name: bank-mitra-web-uat
    restart: always
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bank-mitra-web-uat-http.rule=Host(`uat-bankmitra.tmkcomputers.in`)"
      - "traefik.http.routers.bank-mitra-web-uat-http.entrypoints=web"
      - "traefik.http.routers.bank-mitra-web-uat.rule=Host(`uat-bankmitra.tmkcomputers.in`)"
      - "traefik.http.routers.bank-mitra-web-uat.entrypoints=websecure"
      - "traefik.http.routers.bank-mitra-web-uat.tls=true"
      - "traefik.http.routers.bank-mitra-web-uat.tls.certresolver=myresolver"
      - "traefik.http.services.bank-mitra-web-uat.loadbalancer.server.port=80"

networks:
  traefik_net:
    name: traefik_net
    external: true
```

---

### Step 6: Automated Testing & Verification

Automated E2E testing with Playwright verifies login forms, navigation guards, and API responses:

```typescript
import { test, expect } from '@playwright/test';

test('should load login page and form elements', async ({ page }) => {
  await page.goto('/auth/log-in');
  await expect(page).toHaveTitle(/Approx|Bank Mitra/i);
  await expect(page.locator('input[type="password"]')).toBeVisible();
});
```

---

### Step 7: Build, Push, and Deploy

```bash
# 1. Build images for Prod and UAT
docker compose -f /var/www/vps-infra/code/bank-mitra-web/docker-compose.yml build

# 2. Push to local private registry
docker push localhost:5000/bank-mitra-web:prod
docker push localhost:5000/bank-mitra-web:uat

# 3. Spin up containers
docker compose -f /var/www/vps-infra/code/bank-mitra-web/docker-compose.yml up -d
```

---

## 3. Post-Migration Verification & Rollback Runbook

| Test / Check | Verification Command | Expected Result |
| :--- | :--- | :--- |
| **Prod Web Status** | `curl -i -k -H "Host: bankmitra.tmkcomputers.in" https://127.0.0.1/` | `HTTP/2 200 OK` (Serves `index.html`) |
| **UAT Web Status** | `curl -i -k -H "Host: uat-bankmitra.tmkcomputers.in" https://127.0.0.1/` | `HTTP/2 200 OK` (Serves `index.html`) |
| **SPA Deep Routing** | `curl -i -k -H "Host: bankmitra.tmkcomputers.in" https://127.0.0.1/auth/log-in` | `HTTP/2 200 OK` (Fallback to `index.html` via Nginx `try_files`) |
| **API Connectivity** | Open DevTools Network tab on `https://bankmitra.tmkcomputers.in` | API requests target `https://bankmitra-api.tmkcomputers.in` with CORS `200` |
