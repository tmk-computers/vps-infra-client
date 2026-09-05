# 🏛️ VPS-Infra Client Runtime Architecture & Topology

---

## 🎯 Executive Overview

**VPS-Infra** is an enterprise turn-key DevOps management, multi-database engine, and automated continuous delivery runtime deployed directly onto your Linux VPS.

All microservices run as optimized, containerized runtime images on an isolated Docker network (`traefik_net`), protected by Traefik v3 reverse proxy with automated Let's Encrypt SSL/TLS termination.

---

## 🌐 Platform Architecture Topology

```mermaid
flowchart TD
    subgraph PublicInternet["🌐 Inbound Traffic (HTTPS / 443)"]
        Users["Engineering Team & End Users"]
    end

    subgraph EdgeLayer["🛡️ Edge Security & Routing"]
        Traefik["Traefik v3 Reverse Proxy
        • Automatic Let's Encrypt SSL Certificates
        • Subdomain SNI Routing
        • HTTP to HTTPS Auto-Redirect"]
    end

    subgraph PlatformLayer["📦 Managed Platform Runtime Microservices"]
        DevOpsWeb["DevOps Manager Web (React UI)
        Port: 3000 (Internal)"]
        DevOpsAPI["DevOps Manager API (.NET 10 Engine)
        Port: 8080 (Internal)"]
        CIWeb["CI/CD Dashboard (React UI)
        Port: 5050 (Internal)"]
        CIAPI["CI/CD Pipeline Engine (Node.js)
        Port: 5051 (Internal)"]
        Registry["Private Docker Registry (v2)
        Port: 5000 (Internal)"]
    end

    subgraph DatabaseLayer["💾 Multi-Database Suite (traefik_net)"]
        PG["PostgreSQL 16 (pgvector)
        Port: 5432"]
        Maria["MariaDB 11.x / MySQL
        Port: 3306"]
        MSSQL["MS SQL Server 2022
        Port: 1433"]
        Mongo["MongoDB 7.0 (Optional)
        Port: 27017"]
        Oracle["Oracle 23ai Free (Optional)
        Port: 1521"]
    end

    subgraph AppsLayer["🚀 Deployed Customer Applications & Microservices"]
        App1["Customer Web Applications (Next.js / React / Angular)"]
        App2["Customer Backend APIs (Node / Python / .NET / Java)"]
        App3["AI Native Workloads (FastAPI / Ollama / LangChain)"]
    end

    Users --> Traefik
    Traefik --> DevOpsWeb
    Traefik --> DevOpsAPI
    Traefik --> CIWeb
    Traefik --> CIAPI
    Traefik --> Registry
    Traefik --> App1
    Traefik --> App2
    Traefik --> App3

    DevOpsAPI --> PG
    DevOpsAPI --> Maria
    DevOpsAPI --> MSSQL
    DevOpsAPI --> Mongo
    DevOpsAPI --> Oracle

    CIAPI --> Registry
    CIAPI --> DevOpsAPI
```

---

## 🌐 Distributed Topology (Dedicated CI + Production VPS)

For higher-scale environments with heavy build pipelines, the platform natively supports physical decoupling:

```mermaid
flowchart LR
    DevUsers([Developers / Git Webhooks]) --> MachineA
    ProdUsers([End Users / Customers]) --> MachineB

    subgraph MachineA ["Machine A: Dedicated CI Build Machine"]
        TraefikA[Traefik Proxy] --> CIWeb[CI Dashboard Web]
        TraefikA --> CIAPI[CI Build Engine API]
        TraefikA --> RegistryA[Private Docker Registry]
        CIAPI --> DockerEngineA[(Docker BuildKit)]
        CIAPI -.->|Tag & Push Image| RegistryA
    end

    subgraph MachineB ["Machine B: Client Production VPS"]
        TraefikB[Traefik Proxy] --> DevOpsWeb[DevOps Manager Web]
        TraefikB --> DevOpsAPI[DevOps Manager API]
        TraefikB --> CustApps[Client Application Containers]
        DevOpsAPI --> PostgresB[(Production PostgreSQL)]
        CustApps --> PostgresB
    end

    %% Distributed Communication
    CIAPI == "1. REST API Sync (HTTPS / X-CI-Secret)" ==> DevOpsAPI
    DevOpsAPI -.->|2. Trigger Deploy Webhook| DevOpsAPI
    DevOpsAPI == "3. Pull Built Image" ==> RegistryA
```

### Key Architectural Isolation Guarantees:
1. **Zero Database Exposure**:
   - The CI Server on Machine A does **not** connect to PostgreSQL on Machine B.
   - All synchronization (products, services, build logs, unit/integration test results) streams via authenticated REST endpoints (`/api/ci/sync/*`) over HTTPS using `X-CI-Secret`. PostgreSQL port `5432` remains completely unexposed.
2. **CPU & I/O Protection**:
   - Resource-intensive compiles, Docker layer caching, and browser E2E test executions never starve customer-facing production services.
3. **CORS Security**:
   - The DevOps API enforces strict origin validation (no wildcard `*`), automatically accepting subdomains of `PRIMARY_DOMAIN` and explicit origins configured in `ALLOWED_CORS_ORIGINS`.

---

## 🗄️ Storage & Persistent Volume Layout

All application data, databases, secrets, and build artifacts persist in host directories under `/var/www/vps-infra/volumes`:

```
/var/www/vps-infra/
├── .env                       # Primary domain, SSL email, and credentials
├── docker-compose.yml         # Platform service orchestrator
├── setup.sh                   # 1-Click platform initialization script
├── activate-license.sh        # 1-Click enterprise license activator
├── volumes/
│   ├── apps/                  # Isolated directories for deployed customer apps
│   ├── apk/                   # Mobile APK builds and public distribution downloads
│   ├── artifacts/builds/      # Web and API compiled build artifacts
│   ├── db/
│   │   ├── postgres/data/     # PostgreSQL physical data storage
│   │   ├── postgres/backups/  # Automated nightly database dumps (.sql.gz)
│   │   └── pgadmin/           # pgAdmin session configuration
│   └── license.key            # Enterprise license key storage file
└── network/
    └── traefik/
        ├── acme.json          # Let's Encrypt SSL/TLS certificates storage
        └── users.htpasswd     # Traefik dashboard authentication
```

---

## 🛡️ Security & Isolation Model

1. **Zero External Port Exposure**:
   - Only ports `80/tcp` (HTTP) and `443/tcp` (HTTPS) are exposed to the public internet.
   - Databases (PostgreSQL, MariaDB, SQL Server, MongoDB) and internal APIs communicate exclusively across the private Docker network (`traefik_net`).
2. **Automated SSL/TLS**:
   - Every registered subdomain receives a dedicated SSL certificate via Let's Encrypt ACME HTTP-01 challenge.
3. **Data Sovereignty**:
   - **100% of your data remains on your VPS**. No database records or customer uploads are sent to third-party clouds.
