# 🚨 15-Minute Disaster Recovery & Server Migration Playbook

If your VPS provider experiences an unrecoverable hardware failure or you need to migrate to a larger server, follow this 15-minute complete recovery runbook.

---

## ⏱️ Recovery Workflow Overview

```text
[ Disaster Strikes / New VPS Created ]
                  |
                  v (Minute 0 - 3)
     1. Provision Fresh Ubuntu 24.04 VPS & Clone vps-infra-client
                  |
                  v (Minute 3 - 6)
     2. Restore .env and Run ./setup.sh --license "<KEY>"
                  |
                  v (Minute 6 - 10)
     3. Download Latest Database Dump from Offsite Storage (S3 / Drive)
                  |
                  v (Minute 10 - 12)
     4. Restore Database into PostgreSQL / SQL Server
                  |
                  v (Minute 12 - 15)
     5. Update DNS A-Records to Point to New VPS IP
                  |
                  v
[ Full System Restored & Online with Valid SSL! ]
```

---

## 🛠️ Step-by-Step Restoration Commands

### Step 1: Clone Runtime on New VPS
```bash
sudo mkdir -p /var/www/vps-infra
sudo chown -R $USER:$USER /var/www/vps-infra
git clone https://github.com/tmk-computers/vps-infra-client.git /var/www/vps-infra
cd /var/www/vps-infra
```

### Step 2: Restore Configuration & Launch Stack
```bash
# Copy your saved .env file onto the new server
cp /path/to/saved/.env .env

# Launch platform and activate license
chmod +x setup.sh
./setup.sh --license "YOUR_TMK_LICENSE_KEY"
```

### Step 3: Download & Restore Database Dump
```bash
# Example restoring latest PostgreSQL backup
gunzip -c /path/to/latest_backup.sql.gz | docker exec -i shared_postgres psql -U postgres -d devops_prod
```

### Step 4: Re-Deploy Application Containers
```bash
# Trigger re-deployment of tenant apps from your Git repos
for dir in apps/*/; do
  if [ -f "$dir/docker-compose.yml" ]; then
    docker compose -f "$dir/docker-compose.yml" up -d
  fi
done
```

### Step 5: Update DNS Records
Point your domain A-records (`yourdomain.com`, `*.yourdomain.com`) to the new VPS public IP. Traefik will automatically issue fresh Let's Encrypt certificates within 60 seconds!
