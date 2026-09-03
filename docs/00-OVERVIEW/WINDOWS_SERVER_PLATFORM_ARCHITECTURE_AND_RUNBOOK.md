# 🪟 Windows Server CI/CD & DevOps Platform: Architecture & Implementation Runbook

## Executive Summary

This document provides the complete architecture blueprint, system design, licensing integration, and operational runbook for extending the **VPS-Infra** enterprise platform to **Windows Server 2019 / 2022 / 2025**.

The client requirements are:
- **Target Workloads**: Both **Modern** (.NET 8/9/10, React, Node.js, Python, Android CI) and **Legacy** (.NET Framework 4.5–4.8, classic ASP.NET MVC/WebForms, WCF, Windows Services, IIS sites).
- **Container Policy**: Docker is allowed on the Windows Server.
- **Environments**: Both **Cloud VPS** (AWS EC2, Azure VMs, Contabo, Hetzner) and **On-Premise Dedicated Physical Servers**.
- **Licensing**: Managed centrally via the existing `vps-infra-server` licensing authority (`https://license.tmkcomputers.in`).

---

## 🏛️ 1. Master Architecture Overview

To accommodate both modern containerized microservices and legacy IIS applications simultaneously, the platform operates as a **Unified Hybrid Orchestrator**.

### System Topology Diagram

```text
+===================================================================================================+
|                                  INBOUND INTERNET / HTTPS TRAFFIC                                 |
|                                       (Ports 80 & 443 via DNS)                                    |
+===================================================================================================+
                                                  |
                                                  v
+---------------------------------------------------------------------------------------------------+
|                        TRAEFIK v3 EDGE REVERSE PROXY (DOCKER / WINDOWS)                           |
|  - Automated Let's Encrypt TLS Certificate Resolver (myresolver)                                 |
|  - SNI Host-Header Routing                                                                        |
|  - Dual Routing Engines:                                                                          |
|      1. Docker Provider      --> Routes traffic to internal Docker container network              |
|      2. Dynamic File Provider --> Routes traffic to Host Windows IIS via host.docker.internal     |
+---------------------------------------------------------------------------------------------------+
             |                                                                   |
             | (Internal Docker Network: traefik_net)                            | (host.docker.internal)
             v                                                                   v
+---------------------------------------------------+       +---------------------------------------+
|          CONTROL PLANE MICROSERVICES              |       |       LEGACY WINDOWS WORKLOADS        |
|               (Docker Containers)                 |       |         (Native Windows Host)         |
|---------------------------------------------------|       |---------------------------------------|
|  * devops-api-prod   (ASP.NET Core .NET 10)       |       |  * Legacy ASP.NET 4.x Web Applications|
|  * devops-web-prod   (React Admin Portal UI)      |       |  * Classic WCF / Web Services (IIS)   |
|  * ci-api-prod       (Node.js Build Engine)       |       |  * Native Windows Background Services |
|  * ci-web-prod       (CI/CD Pipeline Dashboard)   |       |  * Host MS SQL Server Database Engine |
|  * shared_postgres   (System Metadata DB)         |       |                                       |
|  * docker-registry   (Private Container Registry) |       |  (IIS Binds locally to 127.0.0.1:8081)|
+---------------------------------------------------+       +---------------------------------------+
             |                                                                   ^
             |                                                                   |
             | (Dispatches Container Builds)                                     | (Dispatches MSBuild / IIS Deploy)
             v                                                                   |
+---------------------------------------------------+                            |
|          MODERN APPLICATION WORKLOADS             |                            |
|               (Docker Containers)                 |                            |
|---------------------------------------------------|                            |
|  * .NET 8 / 9 / 10 Web APIs                       |                            |
|  * React / Angular / Vue Frontends (Nginx)        |                            |
|  * Node.js, Python, Go Microservices              |                            |
+---------------------------------------------------+                            |
             ^                                                                   |
             |========================= CI BUILD RUNNER =========================|
                                  (ci-api-prod Worker)
```

---

## 📊 2. Feasibility & Component Compatibility Matrix

| Platform Component | Linux VPS Implementation | Windows Server Implementation | Compatibility Status |
|---|---|---|:---:|
| **Licensing Authority** | `vps-infra-server/license-server` | Unchanged central server (`license.tmkcomputers.in`) | 🟢 **100% Native** |
| **DevOps Manager API** | ASP.NET Core (.NET 10 Linux Container) | .NET 10 Container (WSL2/Docker) or Windows Service | 🟢 **100% Native** |
| **DevOps & CI Web UIs** | React SPAs served via Nginx | Served via Nginx Container or Host IIS | 🟢 **100% Native** |
| **CI Build Runner Engine** | Node.js `child_process.spawn` | Node.js executing Git, Docker, and MSBuild / PowerShell | 🟢 **100% Compatible** |
| **Edge Reverse Proxy** | Traefik v3 (Linux Docker) | Traefik v3 (Docker) with `host.docker.internal` routing | 🟢 **100% Compatible** |
| **Shared Database** | PostgreSQL 16 (Docker) | PostgreSQL 16 (Docker) or native MS SQL Server | 🟢 **100% Native** |
| **Legacy .NET Framework** | Unsupported on Linux | Built via MSBuild / deployed to Host IIS AppPools | 🟢 **Fully Supported** |

---

## 🔑 3. Licensing Integration with `vps-infra-server`

The licensing engine in `vps-infra-server` enforces HMAC-SHA256 signature validation with optional hardware node locking. The Windows platform supports both commercial tracks:

```text
                                  +-----------------------+
                                  | Client License Request|
                                  +-----------------------+
                                              |
                                              v
                             /---------------------------------\
                            <   Target Deployment Environment?  >
                             \---------------------------------/
                                     /                   \
                        Cloud VPS   /                     \  On-Premise Dedicated
                                   v                       v
                    +-----------------------+   +-----------------------+
                    |    TRACK 1: CLOUD-FLEX |   | TRACK 2: HW-LOCKED    |
                    |-----------------------|   |-----------------------|
                    | * AWS, Azure, Contabo |   | * Dedicated physical  |
                    | * Hardware ID: ANY    |   | * Bound to SHA256 of  |
                    | * Seamless resizing   |   |   Windows MachineGuid |
                    | * Zero downtime on VM |   | * Strict node license |
                    |   reboot/migration    |   |   anti-tamper lock    |
                    +-----------------------+   +-----------------------+
```

### Track 1: Cloud-Flex Mode (Cloud Windows VPS)
- **Target Host**: Azure VM, AWS EC2, Contabo Windows VPS, Hetzner, etc.
- **Hardware Binding**: `ANY` or `GLOBAL` in token payload.
- **Benefit**: The client can resize vCPUs/RAM, reboot across hypervisor nodes, or restore snapshots without breaking the license. No hardware extraction needed before ordering.

### Track 2: Hardware-Locked Mode (Dedicated On-Premise Physical Server)
- **Target Host**: Bare-metal physical server located at client datacenter / premises.
- **Hardware Extraction**: Extract permanent Windows `MachineGuid`:

```powershell
# Run in Administrator PowerShell on the target Windows Server:
$guid = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography").MachineGuid
$bytes = [System.Text.Encoding]::UTF8.GetBytes("TMK-HW-$guid")
$sha = [System.Security.Cryptography.SHA256]::Create()
$fingerprint = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-","").ToLowerInvariant()
Write-Host "`nServer Hardware Fingerprint: $fingerprint`n"
```

### Automatic Hardware Detection in `devops-api`
In `LicenseManagerService.cs`, update the fingerprint resolver to seamlessly support both Linux and Windows:

```csharp
public string GetHardwareFingerprint()
{
    try
    {
        string rawHardware = string.Empty;

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            // Windows: Extract Cryptographic MachineGuid from Registry
            using var key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Cryptography");
            rawHardware = key?.GetValue("MachineGuid")?.ToString() ?? string.Empty;

            if (string.IsNullOrWhiteSpace(rawHardware))
            {
                rawHardware = $"{Environment.MachineName}-{Environment.ProcessorCount}-{Environment.OSVersion}";
            }
        }
        else
        {
            // Linux: Extract /etc/machine-id
            if (File.Exists("/etc/machine-id") && !Directory.Exists("/etc/machine-id"))
            {
                rawHardware = File.ReadAllText("/etc/machine-id").Trim();
            }
            else
            {
                rawHardware = $"{Environment.MachineName}-{Environment.ProcessorCount}-{Environment.OSVersion}";
            }
        }

        using var sha = SHA256.Create();
        var hash = sha.ComputeHash(Encoding.UTF8.GetBytes("TMK-HW-" + rawHardware));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
    catch
    {
        return "00000000000000000000000000000000";
    }
}
```

---

## 🔀 4. Dual-Workload Routing: Unifying Docker and Host IIS

One of the biggest pain points for Windows clients is managing SSL certificates and domain routing across both new Docker microservices and old IIS websites. 

Traefik v3 solves this completely by acting as the **single front-door proxy on Ports 80 & 443**:

```text
[ Internet User: https://legacy-crm.client.com ]
                      |
                      v (Port 443)
       +-------------------------------+
       |   TRAEFIK v3 (Edge Gateway)   |
       |  Auto Let's Encrypt SSL Term  |
       +-------------------------------+
                      |
                      | http://host.docker.internal:8081
                      v
       +-------------------------------+
       |      WINDOWS HOST IIS         |
       |  Site: "Legacy-CRM-Production"|
       |  Binding: 127.0.0.1:8081      |
       |  AppPool: .NET CLR v4.0       |
       +-------------------------------+
```

### Traefik Dynamic Configuration (`C:\vps-infra\traefik\dynamic\legacy-iis-apps.yml`)
```yaml
http:
  routers:
    legacy-crm-router:
      rule: "Host(`legacy-crm.clientdomain.com`)"
      entryPoints:
        - "websecure"
      tls:
        certResolver: "myresolver"
      service: "legacy-crm-service"

  services:
    legacy-crm-service:
      loadBalancer:
        servers:
          - url: "http://host.docker.internal:8081"
```

**Benefits**:
1. **Automated SSL for Legacy Apps**: Legacy ASP.NET 4.0 / 4.5 / 4.8 apps automatically get Let's Encrypt SSL certificates managed by Traefik.
2. **Zero IIS Port Conflicts**: IIS does not need to bind to public port 80 or 443; it binds to internal loopback ports (`127.0.0.1:8081`, `127.0.0.1:8082`), leaving 80/443 for Traefik.

---

## 🛠️ 5. CI/CD Build Engine Pipeline Workflows

The `ci-api` worker detects the repository type and executes the corresponding pipeline:

```text
                       +---------------------------+
                       | Trigger Build (Git Commit)|
                       +---------------------------+
                                     |
                                     v
                       /---------------------------\
                      <   Inspect Repository Meta   >
                       \---------------------------/
                                     |
             +-----------------------+-----------------------+
             |                                               |
             v (Has Dockerfile or Compose)                   v (Has *.sln / *.csproj / web.config)
+-----------------------------------+       +-----------------------------------+
|      MODERN PIPELINE (DOCKER)     |       |       LEGACY PIPELINE (IIS)       |
|-----------------------------------|       |-----------------------------------|
| 1. git pull branch                |       | 1. git pull branch                |
| 2. docker build -t <app>:<tag>    |       | 2. nuget restore                  |
| 3. docker compose up -d           |       | 3. msbuild.exe /p:DeployOnBuild   |
| 4. Healthcheck verification       |       | 4. Stop-WebAppPool                |
| 5. Zero-downtime container swap   |       | 5. Copy-Item to C:\inetpub\wwwroot|
|                                   |       | 6. Start-WebAppPool               |
|                                   |       | 7. IIS HTTP 200 ping test         |
+-----------------------------------+       +-----------------------------------+
```

### Legacy IIS Deployment Script (`deploy-legacy-iis.ps1`)
Used by `ci-api` to deploy compiled .NET Framework apps safely:

```powershell
param(
    [Parameter(Mandatory=$true)][string]$AppName,
    [Parameter(Mandatory=$true)][string]$ArtifactPath,
    [Parameter(Mandatory=$true)][string]$IisSitePath = "C:\inetpub\wwwroot"
)

Import-Module WebAdministration

$targetFolder = Join-Path $IisSitePath $AppName
$backupFolder = "C:\vps-infra\backups\iis\$AppName\$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "📦 Deploying Legacy App: $AppName to $targetFolder"

# 1. Ensure backup directory exists
New-Item -ItemType Directory -Force -Path $backupFolder | Out-Null

# 2. Backup existing version if present
if (Test-Path $targetFolder) {
    Copy-Item -Path "$targetFolder\*" -Destination $backupFolder -Recurse -Force
    Write-Host "✅ Created rollback backup at: $backupFolder"
} else {
    New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
}

# 3. Recycle AppPool during copy
Stop-WebAppPool -Name $AppName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 4. Copy new binaries
Copy-Item -Path "$ArtifactPath\*" -Destination $targetFolder -Recurse -Force

# 5. Restart AppPool
Start-WebAppPool -Name $AppName -ErrorAction SilentlyContinue
Write-Host "🎉 Deployment completed successfully for $AppName"
```

---

## 📁 6. Windows Client Repository Structure (`vps-infra-client-windows`)

```text
C:\vps-infra\
├── .env.example                     # Environment template (domains, SSL email, DB passwords)
├── .env                             # Active environment configuration
├── docker-compose.yml               # Platform control plane (Traefik, DevOps, CI, Postgres)
├── setup.ps1                        # 1-Click Bootstrap installation script
├── activate-license.ps1             # 1-Click CLI license activation tool
├── extract-fingerprint.ps1          # Dedicated on-premise hardware fingerprint extractor
│
├── traefik\
│   ├── traefik.yml                  # Static Traefik config (Docker provider + dynamic watch)
│   └── dynamic\
│       └── legacy-iis-apps.yml      # Reverse proxy routes for host IIS applications
│
├── apps\                            # Docker Compose manifests for tenant apps
│   ├── clever-bill-api\
│   └── bank-mitra-web\
│
├── code\                            # Local Git checkout workspace for CI builds
│   ├── clever-bill-api\
│   └── legacy-crm-app\
│
└── volumes\                         # Persistent storage
    ├── license.key                  # Active enterprise license token
    ├── shared_postgres_data\        # Database data
    ├── traefik_acme\acme.json       # Let's Encrypt SSL certificates
    └── backups\                     # Automated database and IIS backups
```

---

## 🚀 7. Step-by-Step Implementation Files

### A. Windows `docker-compose.yml` (Control Plane)

```yaml
services:
  # Traefik v3 Edge Gateway
  traefik:
    image: traefik:v3.1
    container_name: traefik
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - //./pipe/docker_engine://./pipe/docker_engine
      - C:/vps-infra/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - C:/vps-infra/traefik/dynamic:/etc/traefik/dynamic:ro
      - C:/vps-infra/volumes/traefik_acme:/etc/traefik/acme
    networks:
      - traefik_net
    extra_hosts:
      - "host.docker.internal:host-gateway"

  # Shared PostgreSQL
  shared_postgres:
    image: postgres:16-alpine
    container_name: shared_postgres
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-StrongPostgres123!}
      POSTGRES_DB: ${POSTGRES_DB:-devops_prod}
    volumes:
      - C:/vps-infra/volumes/shared_postgres_data:/var/lib/postgresql/data
    networks:
      - traefik_net

  # DevOps Manager API (.NET 10)
  devops-api-prod:
    image: ${DEVOPS_API_IMAGE:-ghcr.io/tmk-computers/tmk-devops-api:v2.2}
    container_name: devops-api-prod
    restart: always
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:8080
      - TMK_LICENSE_KEY=${TMK_LICENSE_KEY:-}
      - TMK_LICENSE_SERVER=${TMK_LICENSE_SERVER:-https://license.tmkcomputers.in}
      - ConnectionStrings__DefaultConnection=Host=shared_postgres;Port=5432;Database=${POSTGRES_DB:-devops_prod};Username=${POSTGRES_USER:-postgres};Password=${POSTGRES_PASSWORD:-StrongPostgres123!}
    volumes:
      - //./pipe/docker_engine://./pipe/docker_engine
      - C:/vps-infra/volumes/license.key:/app/license.key
      - C:/vps-infra/volumes/backups:/app/backups
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.devops-api.rule=Host(`${DEVOPS_API_HOST:-devops-api.example.com}`)"
      - "traefik.http.routers.devops-api.entrypoints=websecure"
      - "traefik.http.routers.devops-api.tls=true"
      - "traefik.http.routers.devops-api.tls.certresolver=myresolver"
      - "traefik.http.services.devops-api.loadbalancer.server.port=8080"

  # DevOps Web UI (React)
  devops-web-prod:
    image: ${DEVOPS_WEB_IMAGE:-ghcr.io/tmk-computers/tmk-devops-web:v2.2}
    container_name: devops-web-prod
    restart: always
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.devops-web.rule=Host(`${DEVOPS_WEB_HOST:-devops.example.com}`)"
      - "traefik.http.routers.devops-web.entrypoints=websecure"
      - "traefik.http.routers.devops-web.tls=true"
      - "traefik.http.routers.devops-web.tls.certresolver=myresolver"
      - "traefik.http.services.devops-web.loadbalancer.server.port=80"

  # CI Engine API (Node.js)
  ci-api-prod:
    image: ${CI_API_IMAGE:-ghcr.io/tmk-computers/tmk-ci-api:v2.2}
    container_name: ci-api-prod
    restart: always
    environment:
      - PORT=5051
      - DATABASE_URL=Host=shared_postgres;Port=5432;Database=${POSTGRES_DB:-devops_prod};Username=${POSTGRES_USER:-postgres};Password=${POSTGRES_PASSWORD:-StrongPostgres123!}
      - CI_API_PUBLIC_URL=https://${CI_API_HOST:-ci-api.example.com}
      - DEVOPS_API_PUBLIC_URL=https://${DEVOPS_API_HOST:-devops-api.example.com}
    volumes:
      - //./pipe/docker_engine://./pipe/docker_engine
      - C:/vps-infra/code:/var/www/vps-infra/code
      - C:/vps-infra/apps:/var/www/vps-infra/apps
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ci-api.rule=Host(`${CI_API_HOST:-ci-api.example.com}`)"
      - "traefik.http.routers.ci-api.entrypoints=websecure"
      - "traefik.http.routers.ci-api.tls=true"
      - "traefik.http.routers.ci-api.tls.certresolver=myresolver"
      - "traefik.http.services.ci-api.loadbalancer.server.port=5051"

  # CI Web UI (React)
  ci-web-prod:
    image: ${CI_WEB_IMAGE:-ghcr.io/tmk-computers/tmk-ci-web:v2.2}
    container_name: ci-web-prod
    restart: always
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ci-web.rule=Host(`${CI_WEB_HOST:-ci.example.com}`)"
      - "traefik.http.routers.ci-web.entrypoints=websecure"
      - "traefik.http.routers.ci-web.tls=true"
      - "traefik.http.routers.ci-web.tls.certresolver=myresolver"
      - "traefik.http.services.ci-web.loadbalancer.server.port=80"

networks:
  traefik_net:
    name: traefik_net
```

---

### B. `setup.ps1` (1-Click Automated Windows Installer)

```powershell
<#
.SYNOPSIS
    VPS-Infra Windows Server Bootstrap Installer
.DESCRIPTION
    Automates directory structure setup, Docker network initialization,
    environment configuration, and container stack launch.
#>
param(
    [string]$License = "",
    [string]$Tag = "v2.2"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   🚀 VPS-INFRA: 1-CLICK WINDOWS SERVER BOOTSTRAP INSTALLER" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# 1. Verify Prerequisites
Write-Host "`n▶ Step 1: Checking System Prerequisites..." -ForegroundColor Yellow
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "❌ Docker is not installed or not in PATH. Please install Docker Engine or Docker Desktop."
}

# 2. Create Storage Directories
Write-Host "`n▶ Step 2: Creating Platform Storage Directories..." -ForegroundColor Yellow
$dirs = @(
    "volumes\license.key",
    "volumes\shared_postgres_data",
    "volumes\traefik_acme",
    "volumes\backups",
    "code",
    "apps",
    "traefik\dynamic"
)
foreach ($d in $dirs) {
    $p = Join-Path $ScriptDir $d
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
    }
}
Write-Host "✅ Directories verified under $ScriptDir" -ForegroundColor Green

# 3. Create Docker Network
Write-Host "`n▶ Step 3: Ensuring 'traefik_net' Docker Network exists..." -ForegroundColor Yellow
$netCheck = docker network ls --filter name=traefik_net -q
if (-not $netCheck) {
    docker network create traefik_net | Out-Null
    Write-Host "✅ Created 'traefik_net' external network" -ForegroundColor Green
} else {
    Write-Host "✅ 'traefik_net' already exists" -ForegroundColor Green
}

# 4. Copy Environment File if missing
if (-not (Test-Path "$ScriptDir\.env")) {
    if (Test-Path "$ScriptDir\.env.example") {
        Copy-Item "$ScriptDir\.env.example" "$ScriptDir\.env"
        Write-Host "✅ Generated .env from .env.example" -ForegroundColor Green
    }
}

# 5. Launch Stack
Write-Host "`n▶ Step 4: Starting Core Platform Services..." -ForegroundColor Yellow
docker compose -f "$ScriptDir\docker-compose.yml" up -d

# 6. Optional License Activation
if ($License) {
    Write-Host "`n▶ Step 5: Activating Enterprise License..." -ForegroundColor Yellow
    & "$ScriptDir\activate-license.ps1" -LicenseKey $License
}

Write-Host "`n======================================================================" -ForegroundColor Green
Write-Host "   🎉 VPS-INFRA WINDOWS PLATFORM BOOTSTRAP COMPLETED!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
```

---

### C. `activate-license.ps1` (1-Click License Activator)

```powershell
<#
.SYNOPSIS
    VPS-Infra Windows Server Enterprise License Activator
#>
param(
    [string]$LicenseKey = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $LicenseKey) {
    Write-Host "👉 Paste your TMK_LICENSE_KEY token below and press ENTER:" -ForegroundColor Yellow
    $LicenseKey = Read-Host "Token"
}

$LicenseKey = $LicenseKey.Trim().Trim('"').Trim("'")
if (-not $LicenseKey) {
    Write-Error "❌ No license token provided. Activation aborted."
}

Write-Host "`n▶ Step 1: Writing license token to volumes\license.key..." -ForegroundColor Cyan
$volPath = Join-Path $ScriptDir "volumes"
New-Item -ItemType Directory -Force -Path $volPath | Out-Null
$licFile = Join-Path $volPath "license.key"
Set-Content -Path $licFile -Value $LicenseKey -Encoding utf8 -NoNewline
Write-Host "✅ Saved to $licFile" -ForegroundColor Green

Write-Host "`n▶ Step 2: Updating .env file..." -ForegroundColor Cyan
$envPath = Join-Path $ScriptDir ".env"
if (Test-Path $envPath) {
    $lines = Get-Content $envPath
    $updated = $false
    $newLines = foreach ($line in $lines) {
        if ($line -match "^TMK_LICENSE_KEY=") {
            "TMK_LICENSE_KEY=`"$LicenseKey`""
            $updated = $true
        } else {
            $line
        }
    }
    if (-not $updated) {
        $newLines += "TMK_LICENSE_KEY=`"$LicenseKey`""
    }
    $newLines | Set-Content -Path $envPath -Encoding utf8
    Write-Host "✅ Updated TMK_LICENSE_KEY in .env" -ForegroundColor Green
}

Write-Host "`n▶ Step 3: Refreshing devops-api and ci-api..." -ForegroundColor Cyan
docker compose -f "$ScriptDir\docker-compose.yml" up -d devops-api-prod ci-api-prod

Write-Host "`n🎉 Enterprise License Activated Successfully on Windows Server!" -ForegroundColor Green
```

---

## 📅 8. Execution & Delivery Roadmap

```text
+-----------------------------------------------------------------------------------------+
| PHASE 1: Licensing Multi-OS Support                                                     |
| • Update LicenseManagerService.cs to read Windows MachineGuid in devops-manager.        |
| • Re-verify central license generation for Cloud-Flex and Hardware-Locked keys.         |
+-----------------------------------------------------------------------------------------+
                                             |
                                             v
+-----------------------------------------------------------------------------------------+
| PHASE 2: Windows Client Package (vps-infra-client)                                      |
| • Package setup.ps1, activate-license.ps1, and Windows docker-compose.yml.              |
| • Add Traefik dynamic configuration folder for host IIS proxying.                       |
+-----------------------------------------------------------------------------------------+
                                             |
                                             v
+-----------------------------------------------------------------------------------------+
| PHASE 3: Legacy IIS CI/CD Pipeline Automation                                           |
| • Add deploy-legacy-iis.ps1 script for MSBuild / AppPool recycle automation.            |
| • Test dual pipeline: Docker app deployment + IIS legacy app deployment.               |
+-----------------------------------------------------------------------------------------+
                                             |
                                             v
+-----------------------------------------------------------------------------------------+
| PHASE 4: Client Onboarding & UAT                                                        |
| • Hand over the Windows Server Quickstart Runbook to the client.                        |
| • Issue license key from vps-infra-server and verify live heartbeat telemetry.          |
+-----------------------------------------------------------------------------------------+
```
