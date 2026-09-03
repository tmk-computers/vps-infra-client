# 🛠️ Logs, Monitoring & Maintenance

This guide covers real-time operational commands to inspect system logs, monitor resource consumption, and perform routine maintenance.

---

## 📜 1. Inspecting Service Logs

### Live Stream All Platform Logs
```bash
cd /var/www/vps-infra
docker compose logs -f
```

### Inspect a Specific Service
```bash
# DevOps API Backend
docker compose logs -f --tail=100 devops-api-prod

# CI/CD Build Engine
docker compose logs -f --tail=100 ci-api-prod

# Traefik Edge Router
docker compose logs -f --tail=100 traefik
```

### File-Based Application Logs
Application logs are stored persistently under:
`/var/www/vps-infra/volumes/apps/<service-name>/<environment>/logs/`

---

## 📊 2. Monitoring Container Resource Usage

Check CPU and RAM consumption for all active containers:

```bash
docker stats --no-stream
```

Example output:
```text
CONTAINER ID   NAME               CPU %     MEM USAGE / LIMIT     MEM %
a1b2c3d4e5f6   devops-api-prod    0.45%     185MiB / 15.6GiB      1.15%
b2c3d4e5f6a1   ci-api-prod        0.12%     120MiB / 15.6GiB      0.75%
c3d4e5f6a1b2   shared_postgres    0.28%     95MiB / 15.6GiB       0.59%
d4e5f6a1b2c3   traefik            0.05%     45MiB / 15.6GiB       0.28%
```

---

## 🧹 3. Disk Space & Docker Prune Maintenance

Over time, Git builds and dangling Docker images consume disk space. Run the built-in maintenance routine:

```bash
# 1. Remove stopped containers and dangling images
docker image prune -f

# 2. Deep clean build cache (frees several gigabytes)
docker builder prune -a -f

# 3. Check overall disk usage
df -h
```

---

## 🔄 4. Upgrading Platform Containers

When a new version of the VPS-Infra platform is released:

```bash
cd /var/www/vps-infra

# Pull updated images from GitHub Packages
docker compose pull

# Apply updates with zero downtime
docker compose up -d --remove-orphans
```
