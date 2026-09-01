# 📋 Client Onboarding & Operator Guide: VPS-Infra Platform

> **Comprehensive Onboarding Guide for Engineering, QA, and DevOps Teams.**  
> Everything you need to access platform portals, onboard microservices, configure Git push-to-deploy webhooks, connect to multi-engine databases, manage secrets, and operate the platform using the unified `infra` CLI.

---

## 🔑 1. License Activation & Setup

Before accessing platform dashboards, activate your enterprise subscription token provided by TMK Computers:

### Option A: 1-Click CLI Activation (Recommended)
```bash
cd /var/www/vps-infra

# Activate in one command (automatically configures volumes, .env, and restarts microservices)
./activate-license.sh "<YOUR_TMK_LICENSE_KEY>"
```

### Option B: Automatic Activation during Bootstrap
```bash
cd /var/www/vps-infra
./setup.sh --license "<YOUR_TMK_LICENSE_KEY>"
```

### Option C: Web UI Activation
1. Open `https://devops-manager.yourdomain.com` in your browser.
2. The platform will present the **Enterprise License Activation** screen with your server details.
3. Paste your license token and click **Activate License**. Activation is instantaneous (zero downtime).

---

## 🌐 2. Platform Portals & Access Endpoints

Your VPS-Infra instance provides dedicated, SSL-secured endpoints configured via `.env`:

| Service / Portal | Default Subdomain | Description |
| :--- | :--- | :--- |
| **DevOps Manager Panel** | `https://devops-manager.yourdomain.com` | Web UI for application management, rollbacks, and team RBAC. |
| **DevOps Manager REST API**| `https://devops-api.yourdomain.com` | Backend API for deployments, system telemetry, and scheduled jobs. |
| **CI/CD Pipeline Dashboard**| `https://ci.yourdomain.com` | Live build logs, test failure analytics, and code coverage reports. |
| **CI/CD API & Artifacts** | `https://ci-api.yourdomain.com` | Webhook receiver and HTTP 206 streaming APK / build artifact hub. |
| **Private Docker Registry** | `https://registry.yourdomain.com` | Secure private container image storage. |
| **PostgreSQL pgAdmin Web** | `https://pgadmin.yourdomain.com` | Web management interface for PostgreSQL 16 databases. |
| **MariaDB phpMyAdmin Web** | `https://phpmyadmin.yourdomain.com`| Web management interface for MariaDB 11 / MySQL databases. |
| **Traefik Admin Dashboard** | `https://traefik.yourdomain.com` | Real-time reverse proxy, router status & Let's Encrypt TLS monitor. |

---

## 👥 2. Team Member Access & Role Provisioning

### A. Creating Team Accounts (For Administrators)
1. Log in to the **DevOps Manager Panel** (`https://devops-manager.yourdomain.com`) with your SuperAdmin credentials.
2. Navigate to **Access Control** > **Users** (`/users`).
3. Click **Add Team Member** and fill in:
   * **Full Name & Username**
   * **Corporate Email**
   * **Temporary Password**
   * **Primary Role**: 
     - `Admin`: Full cluster and user management.
     - `Developer`: Build triggering, deployments, and log inspection.
     - `QA`: Test reports, build artifacts, and APK downloads.
     - `Viewer`: Read-only system metrics.
4. Share the credentials securely with the team member.

### B. Logging in to the CI Server (For Developers & QA)
1. Open `https://ci.yourdomain.com`.
2. Sign in using your **DevOps Account** credentials (or authorize via a personal **API Bearer Token**).
3. The dashboard will automatically filter accessible repositories based on your role.

---

## 🚀 3. Onboarding a New Application or Microservice

### Step A: Register the Project in the DevOps Panel
1. In the **DevOps Manager Panel**, navigate to **Projects** > **Add New Project** (e.g. `Acme ERP Platform`).
2. Click **Add Service** under your project:
   * **Service Name**: e.g., `acme-api-prod`
   * **Target Directory**: `apps/acme-api`
   * **Environment**: `Prod`, `UAT`, or `QA`
   * **Domain Routing**: Enter your public domain (e.g. `api.acme.com`).
3. Click **Save**. Traefik automatically routes incoming HTTPS traffic and provisions Let's Encrypt SSL certificates.

---

## 🔗 4. Configuring Git Push-to-Deploy Webhooks

Whenever code is pushed or merged into your target branch (e.g. `main` or `release/*`), the CI Server automatically triggers the build pipeline, executes automated tests, generates Docker containers or mobile APKs, and performs zero-downtime deployment.

### Setting up Webhooks in GitHub / GitLab / Bitbucket
1. In the **DevOps Panel**, navigate to **Projects** > your Service > **Webhook Settings**.
2. Copy your **Webhook URL** and **Secret Token**:
   * **Payload URL**: `https://ci-api.yourdomain.com/api/ci/webhook/<SERVICE_ID>`
   * **Secret Header Token**: `x-webhook-token: <YOUR_TOKEN>`
3. In your Git repository (e.g. **GitHub** > **Settings** > **Webhooks** > **Add webhook**):
   * **Payload URL**: Paste the Webhook URL.
   * **Content type**: `application/json`
   * **Secret**: Paste your token.
   * **Events**: Select *Just the push event*.
4. Click **Add Webhook**.

---

## 🗄️ 5. Connecting Applications to the Multi-Database Suite

All database engines run on the high-speed internal Docker network (`traefik_net`). Customer applications connect using the following pre-configured connection parameters:

| Database Engine | Internal Host | Port | Default Database | Configuration Keys in `.env` |
| :--- | :--- | :---: | :--- | :--- |
| **PostgreSQL 16 (`pgvector`)** | `shared_postgres` | `5432` | `devops_prod` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` |
| **MariaDB 11.x / MySQL** | `shared_mariadb` | `3306` | `master_mariadb` | `MARIADB_USER`, `MARIADB_PASSWORD`, `MARIADB_DATABASE` |
| **SQL Server 2022** | `shared_sqlserver` | `1433` | `master` | `MSSQL_SA_PASSWORD` |
| **Oracle 23ai Free** | `shared_oracle` | `1521` | `FREEPDB1` | `ORACLE_PASSWORD`, `ORACLE_APP_USER`, `ORACLE_APP_PASSWORD` |
| **Redis 7 Cache** | `shared_redis` | `6379` | `db 0` | Standard connection string: `shared_redis:6379` |

---

## ⚙️ 6. Managing Environment Variables & Secrets

Each deployed service uses isolated container volume paths for configuration:

* **Production `.env`**: Store application secrets in `/var/www/vps-infra/volumes/apps/<service_name>/prod/.env`
* **Persistent Uploads**: User uploads are mounted at `/var/www/vps-infra/volumes/apps/<service_name>/prod/uploads`
* **Application Logs**: Standardized rotated logs are saved in `/var/www/vps-infra/volumes/apps/<service_name>/prod/logs`

---

## 🧪 7. Automated Testing & Code Quality Gates

Before any service container is promoted to production, the CI Engine automatically validates:
1. **Unit & Integration Tests**: (.NET `dotnet test`, Java Maven `mvn test`, Python `pytest`, Node.js `jest`).
2. **Headless Browser E2E Tests**: Playwright scripts simulating end-user workflows.
3. **Code Coverage Gates**: Enforces minimum line and branch coverage thresholds (LCOV / Cobertura).

If any test suite fails, the deployment is blocked immediately, leaving the active production container unaffected.

---

## ⏪ 8. Instant 1-Click Rollbacks

If an unexpected bug occurs in production:
1. Go to the **DevOps Panel** > **Deploy** tab (`/deploy`).
2. Select your service (e.g. `acme-api-prod`).
3. Under **Branch / Tag**, select your last known good release checkpoint (e.g. `prod-20260829-123456-a1b2c3d`).
4. Click **Deploy Now**.
5. The container will roll back to the exact historical binary in **under 5 seconds**.

---

## 📱 9. Mobile APK Hub (Flutter & React Native)

For mobile projects, every successful CI build creates optimized Android `.apk` binaries:
1. Open the **CI Pipeline Dashboard** at `https://ci.yourdomain.com`.
2. Locate your build card under **Build History**.
3. Click **Download APK** or scan the on-screen **QR Code** directly from your Android test device with **HTTP 206 Partial Content fast streaming**.

---

## 🛠️ 10. Platform Operations via the Unified `infra` CLI

The platform is managed from the command line using the global **`infra`** CLI tool:

```bash
# 1. Deploy / Start all infrastructure services
infra up --vps

# 2. Check live health and container status
infra status

# 3. Stream real-time logs from any service
infra logs devops-api-prod
infra logs ci-api-prod
infra logs traefik_global
infra logs shared_postgres

# 4. Trigger an immediate zero-downtime database snapshot
infra backup

# 5. Restart all services
infra restart

# 6. Stop all platform containers safely
infra down
```

---

## 📦 11. Initial Deployment on a Fresh Linux VPS

To deploy this complete platform on any fresh Ubuntu/Debian Linux VPS:

```bash
# 1. Clone the repository
git clone https://github.com/your-org/vps-infra.git /var/www/vps-infra
cd /var/www/vps-infra

# 2. Configure organization environment variables
cp .env.example .env
nano .env   # Configure your PRIMARY_DOMAIN, SSL email, and passwords

# 3. Launch platform
infra up --vps
```

All Docker networks, volume scaffolding, Traefik Let's Encrypt SSL certificates, databases, the Docker registry, and DevOps Manager will be initialized automatically in under 5 minutes.
