# 📦 Deploying Web APIs & Backend Microservices

This guide shows you how to onboard and deploy containerized backend microservices (Node.js, ASP.NET Core, Python FastAPI, Go, etc.) on your VPS-Infra platform.

---

## 🏛️ How Backend Deployment Works

```text
[ Developer: git push origin main ]
               |
               v (Git Webhook)
      [ VPS-Infra CI Server ]
               |
               +---> 1. Clones repository into /var/www/vps-infra/code/<app>
               +---> 2. Executes automated tests & quality gates
               +---> 3. Builds Docker container image
               +---> 4. Runs `docker compose up -d`
               v
      [ Traefik Edge Proxy ] ---> Automatically binds HTTPS domain with SSL!
```

---

## 📋 Step 1: Prepare Your Application Dockerfile

Ensure your repository has a production Dockerfile in its root.

### Example: ASP.NET Core (.NET 8 / 9 / 10)
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .
RUN dotnet restore
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "YourApp.dll"]
```

### Example: Node.js (Express / NestJS)
```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS final
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

---

## 📝 Step 2: Create App Manifest (`docker-compose.yml`)

Under `/var/www/vps-infra/apps/<your-service-name>/docker-compose.yml`:

```yaml
services:
  my-api-prod:
    image: my-company/my-api:latest
    container_name: my-api-prod
    restart: always
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ConnectionStrings__DefaultConnection=Host=shared_postgres;Port=5432;Database=my_api_db;Username=postgres;Password=YourPostgresPassword;
    volumes:
      - /var/www/vps-infra/volumes/apps/my-api/prod/uploads:/app/uploads
      - /var/www/vps-infra/volumes/apps/my-api/prod/logs:/app/logs
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-api.rule=Host(`api.yourdomain.com`)"
      - "traefik.http.routers.my-api.entrypoints=websecure"
      - "traefik.http.routers.my-api.tls=true"
      - "traefik.http.routers.my-api.tls.certresolver=myresolver"
      - "traefik.http.services.my-api.loadbalancer.server.port=8080"

networks:
  traefik_net:
    external: true
```

---

## 🖥️ Step 3: Register in DevOps Manager Web UI

1. Open `https://devops.yourdomain.com` and log in.
2. Click **"New Project"** -> enter your project name.
3. Click **"Add Service"**:
   - **Service Name**: `my-api-prod`
   - **Git Repository URL**: `https://github.com/your-org/my-api.git`
   - **Git Branch**: `main`
   - **Target Port**: `8080`
   - **Public Hostname**: `api.yourdomain.com`
4. Click **"Save & Deploy"**. The CI engine will automatically build, deploy, and issue Let's Encrypt SSL certificates!
