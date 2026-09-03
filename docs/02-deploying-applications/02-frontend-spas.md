# 🌐 Deploying Frontend SPAs (React, Angular, Vue)

This guide shows you how to package and deploy modern Single Page Applications (SPAs) to VPS-Infra using high-performance Nginx containers with automated Let's Encrypt SSL.

---

## 📋 Step 1: Production Multi-Stage Dockerfile

Add a `Dockerfile` in the root of your frontend repository:

```dockerfile
# Stage 1: Build the static application
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Serve with lightweight Nginx
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```
*(For Angular projects, change `/app/dist` to `/app/dist/<project-name>/browser`)*.

---

## ⚙️ Step 2: Configure `nginx.conf` (SPA Routing Fallback)

To prevent 404 errors when users refresh deep routes (e.g. `/dashboard/settings`), create `nginx.conf` in your repository root:

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, no-transform";
    }
}
```

---

## 📝 Step 3: Create Service Manifest (`docker-compose.yml`)

Under `/var/www/vps-infra/apps/<frontend-app-name>/docker-compose.yml`:

```yaml
services:
  portal-web-prod:
    image: my-company/portal-web:latest
    container_name: portal-web-prod
    restart: always
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portal-web.rule=Host(`app.yourdomain.com`)"
      - "traefik.http.routers.portal-web.entrypoints=websecure"
      - "traefik.http.routers.portal-web.tls=true"
      - "traefik.http.routers.portal-web.tls.certresolver=myresolver"
      - "traefik.http.services.portal-web.loadbalancer.server.port=80"

networks:
  traefik_net:
    external: true
```

---

## 🚀 Step 4: Deploy via DevOps Manager

1. Open `https://devops.yourdomain.com`.
2. Under your Project, click **"Add Service"**.
3. Select **Application Type: Web Application**.
4. Enter your Git URL, branch, and public hostname (`app.yourdomain.com`).
5. Click **"Deploy"**. The app goes live at `https://app.yourdomain.com` in seconds.
