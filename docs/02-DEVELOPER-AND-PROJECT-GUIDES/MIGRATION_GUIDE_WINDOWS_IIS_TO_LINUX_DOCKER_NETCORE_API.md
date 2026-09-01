# Complete Migration Guide: Windows IIS Native .NET Core API to Linux Docker Platform (VPS-Infra)

## Executive Summary & Architecture Overview

This migration guide provides an end-to-end, production-grade runbook for migrating legacy or on-premise **Windows IIS-hosted ASP.NET Core APIs** to modern, containerized **Linux Docker** environments running on the **VPS-Infra** platform (managed with Docker Compose, Traefik Reverse Proxy, Automated Let's Encrypt SSL, and CI/CD).

```
+-----------------------------------------------------------------------------------------+
|                                    VPS-INFRA PLATFORM                                   |
|                                                                                         |
|  +-----------------------------------------------------------------------------------+  |
|  |                   TRAEFIK REVERSE PROXY (SSL / Host Routing)                      |  |
|  |     https://bankmitra-api.tmkcomputers.in   |  https://uat-bankmitra-api...      |  |
|  +---------------------------------------------+-------------------------------------+  |
|                        |                                           |                    |
|                        v (traefik_net)                             v (traefik_net)      |
|  +------------------------------------------+  +-------------------------------------+  |
|  |       bank-mitra-api-prod (Port 8080)    |  |     bank-mitra-api-uat (Port 8080)  |  |
|  |       .NET 9 / ASP.NET Linux Alpine/Deb  |  |     .NET 9 / ASP.NET Linux          |  |
|  +--------------------+---------------------+  +------------------+------------------+  |
|                       |                                           |                     |
|         +-------------+-------------+               +-------------+-------------+       |
|         | Host Volumes:             |               | Host Volumes:             |       |
|         | - /uploads -> /wwwroot/uploads            | - /uploads -> /wwwroot/uploads    |
|         | - /imports -> /wwwroot/FileImportFolder   | - /imports -> /wwwroot/FileImportFolder |
|         | - /logs    -> /Logs                       | - /logs    -> /Logs               |
|         +---------------------------+               +---------------------------+       |
|                                     |                                           |       |
|                                     v                                           v       |
|  +-----------------------------------------------------------------------------------+  |
|  |             SHARED MICROSOFT SQL SERVER 2022 (shared_sql:1433)                    |  |
|  |             Databases: bankmitra_prod | bankmitra_uat                             |  |
|  +-----------------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------------+
```

---

## 1. Key Architectural Differences: Windows IIS vs Linux Docker

| Feature / Behavior | Windows IIS Native | Linux Docker Container |
| :--- | :--- | :--- |
| **File System Path Separator** | Backslash (`\`) or mixed | Strict Forward slash (`/`) |
| **Case Sensitivity** | Case-insensitive (`Uploads` == `uploads`) | Strict case-sensitive (`Uploads` != `uploads`) |
| **File Providers / Directory Creation** | IIS pools often rely on pre-existing folders or auto-provisioning | `PhysicalFileProvider` crashes on startup if directory does not exist on disk |
| **Port Binding** | IIS port 80 / 443 via HTTP.sys | Kestrel binds to `http://+:8080` (or `ASPNETCORE_URLS`) |
| **Static File & Upload Storage** | Physical Windows drive (`C:\inetpub\...` or `D:\uploads`) | Mapped Docker Host Bind Mounts (`/var/www/vps-infra/volumes/...`) |
| **Database Connections** | `Integrated Security=True` (Windows Auth) or SQL Auth | Standard SQL Auth (`Server=shared_sql,1433;User Id=sa;...;TrustServerCertificate=True;`) |
| **Process Management & Restarts** | WAS / IIS Application Pool worker processes (`w3wp.exe`) | Docker daemon `restart: always` + Container Healthcheck |
| **SSL / TLS Termination** | Windows Certificate Store / IIS Bindings | Traefik Reverse Proxy with automated Let's Encrypt TLS challenge |

---

## 2. Step-by-Step Migration Process

### Step 1: Pre-Migration Code Audit & Hardening

Before containerizing, ensure the .NET codebase is platform-agnostic:

1. **Path Handling**:
   - Replace any hardcoded `\` with `Path.Combine(...)` or `/`.
   - Never assume paths are case-insensitive. Ensure filenames and directory references in code match disk casing exactly.

2. **PhysicalFileProvider & Directory Initialization**:
   - When serving static files with `PhysicalFileProvider`, always ensure directory existence before passing to the provider:
   ```csharp
   var uploadsPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads");
   if (!Directory.Exists(uploadsPath))
   {
       Directory.CreateDirectory(uploadsPath);
   }

   app.UseStaticFiles(new StaticFileOptions
   {
       FileProvider = new PhysicalFileProvider(uploadsPath),
       RequestPath = "/uploads"
   });
   ```

3. **External Secrets & JSON Credential Files**:
   - Ensure credential files (e.g. Firebase Admin SDK, Service Account keys) are copied to the build output in `.csproj`:
   ```xml
   <ItemGroup>
     <None Update="FireSecrete\*.json">
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </None>
   </ItemGroup>
   ```
   - Make file resolution resilient across paths:
   ```csharp
   var credentialPath = builder.Configuration["Firebase:CredentialPath"];
   var resolvedPath = Path.IsPathRooted(credentialPath) 
       ? credentialPath 
       : Path.Combine(AppContext.BaseDirectory, credentialPath);
   ```

---

### Step 2: Multi-Stage Linux Dockerfile Creation

Create a multi-stage `Dockerfile` in the root of the API repository. This produces a lean runtime image without the heavy .NET SDK footprint:

```dockerfile
# Stage 1: Build & Publish
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy full source and restore
COPY . .
RUN dotnet restore bca.api/bca.api.csproj
RUN dotnet publish bca.api/bca.api.csproj -c Release -o /app/publish

# Stage 2: Minimal ASP.NET Runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .

# Pre-create volume mount directories
RUN mkdir -p /app/wwwroot/uploads /app/wwwroot/FileImportFolder /app/Logs

# Expose standard ASP.NET Core port
EXPOSE 8080

ENTRYPOINT ["dotnet", "bca.api.dll"]
```

---

### Step 3: Environment Configuration (`appsettings.{Environment}.json`)

Isolate environment-specific configurations into dedicated JSON files and environment variables.

#### `appsettings.Production.json`
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=shared_sql,1433;Database=bankmitra_prod;User Id=sa;Password=YourStrong@Pass123;TrustServerCertificate=True;Connect Timeout=60;MultipleActiveResultSets=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

#### `appsettings.Uat.json`
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=shared_sql,1433;Database=bankmitra_uat;User Id=sa;Password=YourStrong@Pass123;TrustServerCertificate=True;Connect Timeout=60;MultipleActiveResultSets=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information"
    }
  }
}
```

---

### Step 4: Persistent Docker Volume Setup

Uploads, imports, and logs must not reside inside the ephemeral container filesystem. Map them to host directories:

```bash
mkdir -p /var/www/vps-infra/volumes/apps/bankmitra/prod/uploads
mkdir -p /var/www/vps-infra/volumes/apps/bankmitra/prod/imports
mkdir -p /var/www/vps-infra/volumes/apps/bankmitra/prod/logs

mkdir -p /var/www/vps-infra/volumes/apps/bankmitra/uat/uploads
mkdir -p /var/www/vps-infra/volumes/apps/bankmitra/uat/imports
mkdir -p /var/www/vps-infra/volumes/apps/bankmitra/uat/logs

chmod -R 777 /var/www/vps-infra/volumes/apps/bankmitra
```

---

### Step 5: Docker Compose with Traefik Routing & Healthchecks

Create `docker-compose.yml` specifying Production and UAT service definitions, Traefik routing rules, container resource bounds, and health probes:

```yaml
services:
  bank-mitra-api-prod:
    build: .
    image: localhost:5000/bank-mitra-api:${IMAGE_TAG:-prod}
    container_name: bank-mitra-api-prod
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:8080
      - ConnectionStrings__DefaultConnection=Server=shared_sql,1433;Database=bankmitra_prod;User Id=sa;Password=${MSSQL_SA_PASSWORD:-YourStrong@Pass123};TrustServerCertificate=True;Connect Timeout=60;MultipleActiveResultSets=True;
    healthcheck:
      test: ["CMD-SHELL", "pidof dotnet || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 60s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bank-mitra-api-prod.rule=Host(`bankmitra-api.tmkcomputers.in`)"
      - "traefik.http.routers.bank-mitra-api-prod.entrypoints=websecure"
      - "traefik.http.routers.bank-mitra-api-prod.tls=true"
      - "traefik.http.routers.bank-mitra-api-prod.tls.certresolver=myresolver"
      - "traefik.http.services.bank-mitra-api-prod.loadbalancer.server.port=8080"
    volumes:
      - /var/www/vps-infra/volumes/apps/bankmitra/prod/uploads:/app/wwwroot/uploads
      - /var/www/vps-infra/volumes/apps/bankmitra/prod/imports:/app/wwwroot/FileImportFolder
      - /var/www/vps-infra/volumes/apps/bankmitra/prod/logs:/app/Logs
    networks:
      - traefik_net
    restart: always

  bank-mitra-api-uat:
    build: .
    image: localhost:5000/bank-mitra-api:${IMAGE_TAG:-uat}
    container_name: bank-mitra-api-uat
    environment:
      - ASPNETCORE_ENVIRONMENT=Uat
      - ASPNETCORE_URLS=http://+:8080
      - ConnectionStrings__DefaultConnection=Server=shared_sql,1433;Database=bankmitra_uat;User Id=sa;Password=${MSSQL_SA_PASSWORD:-YourStrong@Pass123};TrustServerCertificate=True;Connect Timeout=60;MultipleActiveResultSets=True;
    healthcheck:
      test: ["CMD-SHELL", "pidof dotnet || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 60s
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.bank-mitra-api-uat.rule=Host(`uat-bankmitra-api.tmkcomputers.in`)"
      - "traefik.http.routers.bank-mitra-api-uat.entrypoints=websecure"
      - "traefik.http.routers.bank-mitra-api-uat.tls=true"
      - "traefik.http.routers.bank-mitra-api-uat.tls.certresolver=myresolver"
      - "traefik.http.services.bank-mitra-api-uat.loadbalancer.server.port=8080"
    volumes:
      - /var/www/vps-infra/volumes/apps/bankmitra/uat/uploads:/app/wwwroot/uploads
      - /var/www/vps-infra/volumes/apps/bankmitra/uat/imports:/app/wwwroot/FileImportFolder
      - /var/www/vps-infra/volumes/apps/bankmitra/uat/logs:/app/Logs
    networks:
      - traefik_net
    restart: always

networks:
  traefik_net:
    name: traefik_net
    external: true
```

---

### Step 6: Automated Testing & Verification in Docker

Because host environments may not have the exact .NET SDK installed directly on the bare OS, run unit and integration tests inside an ephemeral Docker container:

```bash
docker run --rm \
  -v /var/www/vps-infra/code/bank-mitra-api:/src \
  -w /src \
  mcr.microsoft.com/dotnet/sdk:9.0 \
  dotnet test bca.api.Tests/bca.api.Tests.csproj --logger "console;verbosity=detailed"
```

---

### Step 7: CI/CD Pipeline & Registry Push

Build and push the versioned container images to the local private registry (`localhost:5000`):

```bash
# 1. Build and tag
docker compose -f /var/www/vps-infra/code/bank-mitra-api/docker-compose.yml build

# 2. Push to local registry
docker push localhost:5000/bank-mitra-api:prod
docker push localhost:5000/bank-mitra-api:uat

# 3. Deploy
docker compose -f /var/www/vps-infra/code/bank-mitra-api/docker-compose.yml up -d
```

---

### Step 8: Post-Migration Verification Checklist

1. **Verify Container Health**:
   ```bash
   docker ps --filter "name=bank-mitra-api"
   ```
2. **Verify Traefik Routing & HTTPS**:
   ```bash
   curl -i -k -H "Host: bankmitra-api.tmkcomputers.in" https://127.0.0.1/health
   curl -i -k -H "Host: uat-bankmitra-api.tmkcomputers.in" https://127.0.0.1/health
   ```
3. **Verify Volume Persistence**:
   - Create a test file in `/var/www/vps-infra/volumes/apps/bankmitra/prod/uploads/test.txt`.
   - Access via container `/app/wwwroot/uploads/test.txt` and ensure write-back succeeds.

---

## 3. Rollback & Troubleshooting Runbook

| Symptom | Probable Cause | Action |
| :--- | :--- | :--- |
| **502 Bad Gateway from Traefik** | Kestrel crashed during startup or is binding to localhost instead of `0.0.0.0:8080`. | Inspect logs: `cat /var/www/vps-infra/volumes/apps/bankmitra/prod/logs/*.log`. Ensure `ASPNETCORE_URLS=http://+:8080`. |
| **`DirectoryNotFoundException: wwwroot/uploads`** | Directory missing prior to `PhysicalFileProvider` creation. | Wrap in `Directory.CreateDirectory(...)` in `Program.cs` before static file registration. |
| **Database Login Failed / Timeout** | `shared_sql` container is starting up or SA password mismatch. | Verify `shared_sql` health with `docker ps --filter "name=sql"`. Test connection with `sqlcmd` or check `.env` `MSSQL_SA_PASSWORD`. |
| **SSL Certificate Error on New Domain** | DNS A record for the domain does not point to VPS public IP. | Ensure DNS record `bankmitra-api.tmkcomputers.in` points to the VPS public IP so Let's Encrypt HTTP-01 challenge succeeds. |
