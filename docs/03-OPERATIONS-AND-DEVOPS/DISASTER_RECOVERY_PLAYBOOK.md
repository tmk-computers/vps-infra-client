# 🚨 Disaster Recovery & Server Migration Playbook

This document defines the disaster recovery (DR) procedures and step-by-step instructions for recovering or migrating the entire **Managed VPS CI/CD Platform** to a new VPS server in **under 15 minutes**.

---

## 🕒 Recovery Time & Point Objectives
* **RTO (Recovery Time Objective)**: < 15 minutes (Full system rebuilt on fresh server).
* **RPO (Recovery Point Objective)**: < 24 hours (or matching your automated snapshot schedule).

---

## 🗄️ 1. Backup Strategy Overview

The platform automatically manages three layers of backup:

1. **Database Dumps (PostgreSQL & SQL Server)**:
   - Stored locally at `/var/www/vps-infra/volumes/db-backups/`
   - Generated daily at **2:00 AM IST** via automated Hangfire scheduled jobs.
2. **Persistent App Volumes & Uploads**:
   - Stored in `/var/www/vps-infra/volumes/apps/`
3. **Offsite Cloud Sync (Recommended)**:
   - Synchronized daily to AWS S3, Cloudflare R2, or Google Drive via backup worker.

---

## 🚀 2. Full Server Migration / Disaster Recovery (Step-by-Step)

If the active VPS hardware fails or you need to migrate to a new hosting provider (e.g. migrating from Linode to Hetzner / AWS EC2):

### Step 1: Provision New Clean VPS
1. Launch a fresh VPS with **Ubuntu 22.04 LTS or 24.04 LTS** (Recommended: 4 vCPU, 16 GB RAM).
2. Update DNS records (A Records for `*.yourdomain.com` or root domain) to point to the new VPS IP address.

### Step 2: Clone Infrastructure Repository & Run Bootstrap Installer
SSH into the new VPS as `root`:
```bash
# 1. Clone your infrastructure repository
mkdir -p /var/www
cd /var/www
git clone <YOUR_GIT_REPO_URL> vps-infra
cd vps-infra

# 2. Run the automated bootstrap installer
chmod +x scripts/*.sh
./scripts/setup-vps.sh
```

### Step 3: Apply Linux Kernel & Network Tuning
Ensure performance optimizations are active on the new server:
```bash
./scripts/optimize-vps-limits.sh
```

### Step 4: Restore Database Backups & Volume Uploads
Copy your latest backup archives from offsite storage to `/var/www/vps-infra/volumes/`:

#### A. Restore PostgreSQL Databases
```bash
# Restore main DevOps Panel & project databases
docker exec -i shared_postgres pg_restore -U postgres -d devops_prod /var/www/vps-infra/volumes/db-backups/latest_devops_prod.dump
```

#### B. Restore Microsoft SQL Server Databases (If Applicable)
```bash
# Restore MSSQL database snapshot
docker exec -i shared_sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "
RESTORE DATABASE SchoolDb FROM DISK = '/var/opt/mssql/backup/latest_SchoolDb.bak' WITH REPLACE;"
```

#### C. Unpack Uploaded Media & Files
```bash
# Restore persistent uploads
tar -xzf app_volumes_backup.tar.gz -C /var/www/vps-infra/volumes/apps/
```

### Step 5: Start All Platform Services
```bash
cd /var/www/vps-infra/network/traefik && docker compose up -d
cd /var/www/vps-infra/docker-registry && docker compose up -d
cd /var/www/vps-infra/db/postgres && docker compose up -d
cd /var/www/vps-infra/devops-manager && docker compose up -d
cd /var/www/vps-infra/ci-server && docker compose up -d
```

Traefik will immediately obtain fresh SSL certificates from Let's Encrypt, and your entire CI/CD, DevOps management panels, and active production containers will resume serving traffic.

---

## 🛡️ 3. Post-Recovery Verification Checklist
- [ ] Log in to `https://devops.yourdomain.com` and verify all services show green health status.
- [ ] Check `https://devops.yourdomain.com/users` to verify user accounts and roles are intact.
- [ ] Trigger a test build on `https://ci.yourdomain.com` to ensure compiler SDKs and caches are operational.
- [ ] Test public web apps and APIs to confirm database connectivity and SSL verification.
