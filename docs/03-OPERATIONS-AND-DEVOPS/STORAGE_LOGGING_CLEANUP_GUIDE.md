# 🧹 Infrastructure Guide: Storage, Logging, & Scheduled Cleanups

This guide documents the volume directory standards, logging configurations, automated cleanup policies, and CI test integrations for developers and administrators working in the `vps-infra` workspace.

---

## 1. Storage & Volume Standards

All applications deployed in this infrastructure map their persistent uploads and active log files to standardized path layouts on the host system:

* **Host Volume Path**: `/var/www/vps-infra/volumes/apps/<volume-folder>/<environment>/`
  * `<volume-folder>`: Matches the lowercase service folder name (e.g., `kakshaplus`, `cleverbill`, `omr`, `cleverfarmer`, `cleverlord`, `cleversales`).
  * `<environment>`: E.g., `dev`, `qa`, `uat`, `prod`.

### Volumes Mapping in `docker-compose.yml`
When adding or updating microservices, always mount folders to these host volume layouts:

```yaml
services:
  app-service-uat:
    volumes:
      # Uploads mapping
      - /var/www/vps-infra/volumes/apps/cleverbill/uat/uploads:/app/uploads
      # Active logs mapping
      - /var/www/vps-infra/volumes/apps/cleverbill/uat/logs:/app/logs
```

---

## 2. Rotational Application Logging

To prevent logs from filling up container filesystems, all projects must write logs to the mounted `/app/logs` (or `/app/Logs`) folder and configure daily/size-based rotational parameters.

### Spring Boot (Java) Configuration
Add the following properties in `src/main/resources/application.properties` to rotate files when they exceed `5MB` and keep up to 7 days of logs:

```properties
logging.file.name=logs/app.log
logging.logback.rollingpolicy.max-file-size=5MB
logging.logback.rollingpolicy.max-history=7
```

### Python Configuration
Use Python's standard `TimedRotatingFileHandler` inside application logging setups to rotate files daily at midnight:

```python
from logging.handlers import TimedRotatingFileHandler
from pathlib import Path

LOG_FILE_PATH = Path("logs/omr_ai_service.log")

file_handler = TimedRotatingFileHandler(
    LOG_FILE_PATH,
    when="midnight",
    interval=1,
    backupCount=7,
    encoding="utf-8"
)
```

---

## 3. Automated Storage & Database Cleanup

A scheduled background job in the DevOps Panel (running at **3:00 AM IST daily**) automates disk and database maintenance to prevent the 200 GB volume from running out of space.

### Docker Storage & Cache Pruning
The cleanup task executes the following:
* **Stopped Containers**: `docker container prune -f`
* **Unused Networks**: `docker network prune -f`
* **Unused Images**: `docker image prune -a -f`
* **Builder Cache (BuildKit)**: `docker builder prune -a -f` (Reclaims massive space used by CI builds).

### Local Docker Registry Garbage Collection
Our private Docker registry (`localhost:5000`) is configured with image deletion support:
* **Registry Flag**: `REGISTRY_STORAGE_DELETE_ENABLED: "true"`
* **Scheduled Job**: Runs garbage collection daily inside the container to physically reclaim storage occupied by overwritten tags:
  ```bash
  docker exec docker-registry-backend registry garbage-collect /etc/docker/registry/config.yml
  ```

### Database Log Pruning (14-Day Retention)
To prevent the DevOps database (`devops_prod`) from growing indefinitely due to text-heavy console records, the service runs database pruning daily to keep only the last **14 days** of logs (configurable via `LOG_RETENTION_DAYS` in [.env.example](file:///var/www/vps-infra/.env.example)):
* Clears `SystemLogs` older than 14 days.
* Clears `DeploymentLogs` (heavy terminal console output) older than 14 days.
* Clears `ci_build_logs` (heavy CI build stdout) older than 14 days (cascades to associated test runs inside `ci_build_tests`).

---

## 4. Kernel Performance & Socket Optimization

To maintain high I/O throughput across database operations and multi-tier container networking, run the kernel optimizer script:
* **Script**: [`scripts/optimize-vps-limits.sh`](file:///var/www/vps-infra/scripts/optimize-vps-limits.sh)
* **Parameters**: Sets `vm.swappiness=10`, `max_map_count=262144`, and socket backlog limits to 65,535.
