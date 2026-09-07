# 📖 VPS-Infra Customer Documentation Hub

Welcome to the **VPS-Infra** customer documentation center. Follow the sequential guide below to install, configure, deploy applications, and operate your private DevOps and CI/CD platform.

---

## 🧭 Step-by-Step Learning & Operating Path

```text
+---------------------------------------------------------------------------------------------------+
|                                  THE 4-STEP OPERATIONAL JOURNEY                                   |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|   [ STEP 1: GETTING STARTED ] ────────► [ STEP 2: DEPLOYING APPS ]                                |
|   • Linux VPS Installation              • Web APIs (Node, .NET, Python)                           |
|   • Enterprise License Activation       • Frontend SPAs (React, Angular)                          |
|                                         • Mobile CI/CD (Android APKs)                             |
|                                                     │                                             |
|                                                     ▼                                             |
|   [ STEP 4: OPERATIONS & RECOVERY ] ◄── [ STEP 3: DATABASES ]                                     |
|   • Logs & System Monitoring            • Multi-Database Connection Strings                       |
|   • SSL & Domain Troubleshooting        • Automated Backups & Cloud Sync                          |
|   • 15-Minute Disaster Recovery                                                                   |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```

---

## 📑 Complete Document Index

### 🚀 Step 1: Getting Started
1. [`01-getting-started/01-linux-vps-installation.md`](01-getting-started/01-linux-vps-installation.md): Ubuntu 22.04/24.04 LTS installation, DNS configuration, `.env` guide, and bootstrap installer.
2. [`01-getting-started/03-license-activation.md`](01-getting-started/03-license-activation.md): Requesting and activating Cloud-Flex (Cloud VPS) or Hardware-Locked (On-Premise) license keys.

### 📦 Step 2: Deploying Applications
1. [`02-deploying-applications/01-web-apis.md`](02-deploying-applications/01-web-apis.md): Onboarding and deploying Node.js, ASP.NET Core (.NET 8/9/10), and Python FastAPI microservices.
2. [`02-deploying-applications/02-frontend-spas.md`](02-deploying-applications/02-frontend-spas.md): Packaging and deploying React, Angular, and Vue SPAs with Nginx and Let's Encrypt SSL.
3. [`02-deploying-applications/03-mobile-ci-cd.md`](02-deploying-applications/03-mobile-ci-cd.md): Automated Android APK compilation for Flutter, React Native, and Native Android.


### 💾 Step 3: Database Management
1. [`03-database-management/01-database-connections.md`](03-database-management/01-database-connections.md): Internal Docker DNS connection strings for PostgreSQL, MariaDB, SQL Server, and MongoDB.
2. [`03-database-management/02-automated-backups.md`](03-database-management/02-automated-backups.md): Automated daily backups, manual dumps, offsite S3/Google Drive synchronization, and restore commands.

### 🛠️ Step 4: Operations & Troubleshooting
1. [`04-operations-and-troubleshooting/01-logs-and-monitoring.md`](04-operations-and-troubleshooting/01-logs-and-monitoring.md): Inspecting container logs, monitoring memory/CPU stats, disk pruning, and container updates.
2. [`04-operations-and-troubleshooting/02-ssl-domain-troubleshooting.md`](04-operations-and-troubleshooting/02-ssl-domain-troubleshooting.md): Troubleshooting Traefik Let's Encrypt certificates, Cloudflare DNS-Only configuration, and HTTP 502/404 errors.
3. [`04-operations-and-troubleshooting/03-disaster-recovery.md`](04-operations-and-troubleshooting/03-disaster-recovery.md): Complete 15-minute server migration and rebuild runbook.
