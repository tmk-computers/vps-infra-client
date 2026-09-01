# 🚀 VPS-Infra Unified CLI (`infra`): Developer & Operator Guide

> **Official Command-Line Interface (CLI) Reference for the VPS-Infra Platform.**  
> Control, deploy, monitor, and backup your entire single-VPS infrastructure with a single global command.

---

## 📦 1. Installation & Setup

The `infra` CLI is globally installed at `/usr/local/bin/infra` and symlinked to `/var/www/vps-infra/infra`.

To verify installation from any terminal directory:

```bash
infra --help
```

---

## 🛠️ 2. Command Reference

### `infra up` / `infra up --vps`
Initializes and starts all core platform services in the correct dependency order:
1. Traefik v3 Global Edge Proxy & Let's Encrypt SSL resolver.
2. Shared PostgreSQL 16 (with `pgvector`) & pgAdmin.
3. Private Docker Registry & Registry UI.
4. DevOps Manager API (.NET 10) & Web Dashboard (React).
5. CI/CD Server Engine (Node.js) & Web Dashboard.

```bash
infra up
# or
infra up --vps
```

---

### `infra status` / `infra ps`
Displays the real-time container health, uptime, and active listening ports of all running platform services.

```bash
infra status
```

**Example Output:**
```text
📊 VPS-INFRA CONTAINER STATUS:
NAMES                        STATUS                  PORTS
ci-web-prod                  Up 10 minutes           80/tcp
ci-api-prod                  Up 17 minutes           5051/tcp
devops-web-prod              Up 15 hours             80/tcp
devops-api-prod              Up 15 hours (healthy)   8080/tcp
traefik_global               Up 19 hours             :80, :443
docker-registry-ui           Up 6 days               80/tcp
docker-registry-backend      Up 6 days               :5000
shared_postgres              Up 2 weeks (healthy)    :5432
```

---

### `infra logs <service>`
Streams live, colorized standard output and error logs from any platform container.

```bash
# View DevOps Manager API backend logs
infra logs devops-api-prod

# View CI/CD Server API backend logs
infra logs ci-api-prod

# View Traefik proxy access logs
infra logs traefik_global

# View PostgreSQL database engine logs
infra logs shared_postgres
```

---

### `infra backup`
Triggers an immediate, zero-downtime SQL dump of the main platform database (`devops_prod`) and stores the timestamped archive in `volumes/db/postgres/backups/`.

```bash
infra backup
```

**Output:**
```text
▶ Triggering automated backup for devops_prod...
✅ Backup saved to: /var/www/vps-infra/volumes/db/postgres/backups/devops_prod_20260830_074500.sql
```

---

### `infra restart`
Gracefully stops and restarts all platform infrastructure containers while preserving all persistent volume data.

```bash
infra restart
```

---

### `infra down`
Gracefully halts all platform infrastructure containers. Persistent data in `/var/www/vps-infra/volumes` remains safely preserved.

```bash
infra down
```

---

## ⚙️ 3. Environment & Configuration

The CLI automatically sources variables from `/var/www/vps-infra/.env`. 

Key configuration keys:
```bash
PRIMARY_DOMAIN=yourdomain.com
DEVOPS_WEB_HOST=devops.yourdomain.com
DEVOPS_API_HOST=devops-api.yourdomain.com
CI_WEB_HOST=ci.yourdomain.com
CI_API_HOST=ci-api.yourdomain.com
POSTGRES_DB=devops_prod
POSTGRES_PASSWORD=YourStrongPassword
```

---

## 🛡️ 4. Quick Troubleshooting

| Symptom | Cause | Resolution Command |
| :--- | :--- | :--- |
| `infra: command not found` | Symlink missing from PATH | `ln -sf /var/www/vps-infra/infra /usr/local/bin/infra` |
| Traefik returns `404 page not found` | Subdomain mismatch in `.env` | Run `infra restart` to reload Traefik labels from `.env` |
| Container shows `unhealthy` | DB starting or port occupied | Check logs with `infra logs <container-name>` |
