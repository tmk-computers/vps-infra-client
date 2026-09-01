# 🚀 VPS-Infra Enterprise Platform

[![Docker](https://img.shields.io/badge/Docker-Compose_v2-blue.svg?logo=docker)](https://www.docker.com/)
[![Traefik](https://img.shields.io/badge/Traefik-v3_Edge_Gateway-2496ED.svg?logo=traefik)](https://traefik.io/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16_LTS-336791.svg?logo=postgresql)](https://www.postgresql.org/)
[![Status](https://img.shields.io/badge/Status-Production_Ready-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-TMK_Enterprise-indigo.svg)](https://tmkcomputers.in)

**VPS-Infra** is an enterprise-grade, turn-key DevOps management and CI/CD distribution runtime. It provides automated multi-tenant microservice deployment, Traefik edge routing with automated SSL certificates, a multi-database engine suite, and automated continuous delivery.

---

## 🏛️ Architecture Overview

```mermaid
flowchart TD
    subgraph Internet["🌐 Inbound Traffic (HTTPS)"]
        User["Client Developers & End Users"]
    end

    subgraph Edge["🛡️ Edge Reverse Proxy & Security"]
        Traefik["Traefik v3 (Auto Let's Encrypt SSL)"]
    end

    subgraph Platform["📦 Platform Runtime Microservices"]
        DevOpsWeb["DevOps Manager Web (React UI)"]
        DevOpsAPI["DevOps Manager API (.NET 10)"]
        CIWeb["CI Server Web (Build Dashboard)"]
        CIAPI["CI Server API (Pipeline Engine)"]
        Registry["Private Docker Registry (v2)"]
    end

    subgraph Databases["💾 Multi-Database Suite"]
        PG["PostgreSQL 16"]
        Maria["MariaDB 11.x"]
        MSSQL["MS SQL Server 2022"]
        Mongo["MongoDB 7.0"]
        Oracle["Oracle 23ai"]
    end

    User --> Traefik
    Traefik --> DevOpsWeb
    Traefik --> DevOpsAPI
    Traefik --> CIWeb
    Traefik --> CIAPI
    Traefik --> Registry
    DevOpsAPI --> Databases
```

---

## 💻 Hardware & System Requirements

| Specification | Minimum | Recommended |
|---|---|---|
| **Operating System** | Ubuntu 22.04 / 24.04 LTS | Ubuntu 24.04 LTS (x86_64) |
| **CPU** | 2 vCPUs | 4+ vCPUs |
| **RAM** | 4 GB | 8 GB – 16 GB |
| **Disk Storage** | 40 GB NVMe / SSD | 100 GB+ SSD |
| **Docker Engine** | Docker v24.0+ | Docker v26.0+ & Compose v2 |
| **Open Firewall Ports** | `80/tcp`, `443/tcp` | `80/tcp`, `443/tcp` |

---

## 🚀 Quickstart Installation (6 Steps)

### Step 1: Clone the Runtime Repository
Clone this repository to your target VPS host:
```bash
git clone https://github.com/tmk-computers/vps-infra-client.git /var/www/vps-infra
cd /var/www/vps-infra
```

### Step 2: Configure Environment Variables
Copy `.env.example` to `.env` and fill in your company branding and admin credentials:
```bash
cp .env.example .env
nano .env
```

Key fields to configure:
```ini
# Primary Domain & SSL Contact
PRIMARY_DOMAIN=yourdomain.com
ACME_SSL_EMAIL=admin@yourdomain.com
COMPANY_NAME="Your Company Name"

# Initial SuperAdmin Credentials
SUPERADMIN_EMAIL=admin@yourdomain.com
SUPERADMIN_PASSWORD=YourStrongPassword123!
```

### Step 3: Configure DNS A Records
Point the following **A Records** with your DNS provider (Cloudflare, Route53, GoDaddy) to your VPS Public IP address:

| Subdomain | Description | Example URL |
|---|---|---|
| `@` / `yourdomain.com` | Primary Landing / Gateway | `https://yourdomain.com` |
| `devops-manager` | DevOps Management Web UI | `https://devops-manager.yourdomain.com` |
| `devops-api` | DevOps Backend API | `https://devops-api.yourdomain.com` |
| `ci` | CI/CD Dashboard | `https://ci.yourdomain.com` |
| `ci-api` | CI/CD Build Engine API | `https://ci-api.yourdomain.com` |
| `registry` | Docker Container Registry | `https://registry.yourdomain.com` |
| `pgadmin` | PostgreSQL Web Admin *(Optional)* | `https://pgadmin.yourdomain.com` |
| `traefik` | Traefik Routing Dashboard | `https://traefik.yourdomain.com` |

---

### Step 4: Obtain Server Hardware Fingerprint
If requesting an on-premise hardware-locked license, extract your server's hardware fingerprint:

```bash
# Method 1 (Direct from Linux host shell - Recommended):
echo -n "TMK-HW-$(cat /etc/machine-id)" | sha256sum | awk '{print $1}'
```
*(Returns your unique 64-character server hash, e.g. `b9e4ee73b6b7a630...`).*

> 💡 **Tip**: If you are deploying on dynamic cloud infrastructure (AWS, DigitalOcean, Hetzner, GCP), you can alternatively request a **Cloud-Flex** license, which does not require a hardware fingerprint and allows seamless cloud resizing.

---

### Step 5: Send Fingerprint to TMK Computers for License Key
Send your hardware fingerprint (or company name for Cloud-Flex) to the **TMK Computers Licensing Team** (`licensing@tmkcomputers.in` or via your dedicated account manager).

TMK Computers will issue your cryptographically signed `TMK_LICENSE_KEY` token.

---

### Step 6: Run Bootstrap & Activate License (1-Click)
Apply your signed license token using any of these frictionless methods:

#### Option A: 1-Click CLI Script (Recommended)
```bash
cd /var/www/vps-infra

# Automatically configures volume storage, .env, container refresh, and status check:
./activate-license.sh "YOUR_SIGNED_TMK_LICENSE_KEY"
```

#### Option B: Fresh Bootstrap Script with License Flag
```bash
cd /var/www/vps-infra
chmod +x setup.sh
./setup.sh --license "YOUR_SIGNED_TMK_LICENSE_KEY"
```

#### Option C: Live Web UI Activation
1. Navigate to `https://devops-manager.yourdomain.com` in your browser.
2. Paste the token into the **Subscription Lock Screen** modal and click **Activate License**. Activation takes effect **hot in-memory with zero container downtime**.

---

## 🔑 Enterprise Licensing: Cloud-Flex & Hardware-Locked Modes

The VPS-Infra runtime enforces cryptographic HMAC-SHA256 enterprise subscription validation. The platform natively supports two licensing deployment modes depending on your infrastructure topology:

```mermaid
flowchart TD
    subgraph LicenseTypes["🔑 TMK Enterprise License Token Types"]
        CloudFlex["☁️ Cloud-Flex Mode (Recommended for Cloud VPS)
        • Dynamic hardware binding (null / ANY)
        • AWS, DigitalOcean, Hetzner, GCP, Azure
        • Seamless droplet resize & snapshot migration"]
        
        HWLocked["🔒 Hardware-Locked Mode (Dedicated On-Premise)
        • Bound to 64-char SHA256 machine-id
        • Bare-metal physical servers & private datacenters
        • Strict physical node security compliance"]
    end
```

### ☁️ 1. Cloud-Flex Mode (Recommended for Cloud VPS)
* **What it is**: A flexible cryptographic license that is **not** locked to a single physical hardware ID.
* **Why use it**: Cloud virtual machines (AWS EC2, DigitalOcean Droplets, Hetzner Cloud, GCP) frequently change underlying hypervisors when you upgrade RAM/CPU, reboot across host nodes, or restore from snapshots.
* **Benefits**:
  - ✅ **Zero-Downtime Resizing**: Upgrade your VPS vCPUs and RAM without invalidating your license.
  - ✅ **Snapshot & DR Mobility**: Restore backup snapshots to a new region or host seamlessly.
  - ✅ **No Pre-Registration Required**: You do not need to extract a machine fingerprint beforehand; simply request a **Cloud-Flex** token for your company name.

### 🔒 2. Hardware-Locked Mode (For Dedicated / On-Premise)
* **What it is**: A license locked to your server's unique 64-character SHA-256 hardware fingerprint (`SHA256("TMK-HW-" + /etc/machine-id)`).
* **Why use it**: Ideal for high-security on-premise installations, enterprise private clouds, or bare-metal servers requiring strict compliance.
* **Obtaining Server Hardware Fingerprint**: See [Step 4](#step-4-obtain-server-hardware-fingerprint) above.
* **Activating Your License**: See [Step 6](#step-6-run-bootstrap--activate-license-1-click) above.

---

## 🛠️ Day-2 Operations & Maintenance

### Starting & Stopping Services
```bash
# Start all services in background
docker compose up -d

# Check real-time service status
docker compose ps

# View live aggregate logs
docker compose logs -f

# View logs for a specific service
docker compose logs -f devops-api-prod
```

### Managing Database Engines
```bash
# Check status of all database engines
./db/manage-databases.sh status

# Start or stop specific engines
./db/manage-databases.sh start postgres
./db/manage-databases.sh start mariadb
./db/manage-databases.sh start mongodb
```

### Upgrading Container Images
```bash
# Pull latest container images
docker compose pull

# Apply updates with zero downtime
docker compose up -d --remove-orphans
```

---

## 📞 Support & Inquiries

For license renewals, enterprise support contracts, or custom infrastructure configurations:
* **Website**: [https://tmkcomputers.in](https://tmkcomputers.in)
* **Email Support**: `support@tmkcomputers.in` / `sales@tmkcomputers.in`
* **Documentation**: [https://docs.tmkcomputers.in](https://docs.tmkcomputers.in)

---

*© 2026 TMK Computers. All Rights Reserved.*
