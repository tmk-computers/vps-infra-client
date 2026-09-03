# 💾 Automated Database Backups & Offsite Sync

VPS-Infra includes automated, scheduled daily database dumps with compression and offsite synchronization capabilities to prevent data loss.

---

## ⏰ 1. Automated Backup Schedules

* By default, the platform executes an automated backup of all active databases every night at **02:00 UTC**.
* Backup archives are stored under `/var/www/vps-infra/volumes/backups/`.
* Backups are compressed with gzip (`.sql.gz`) and timestamped:
  `backup_devops_prod_20260903_020000.sql.gz`

---

## 🚀 2. Creating a Manual Backup Anytime

### Via Web UI
1. Navigate to `https://devops.yourdomain.com`.
2. Under **Databases**, select your target database.
3. Click **"Create Backup Now"**. The file is generated and immediately available for 1-click download.

### Via CLI Command
```bash
# PostgreSQL Backup
docker exec -t shared_postgres pg_dump -U postgres -d devops_prod | gzip > /var/www/vps-infra/volumes/backups/manual_postgres_$(date +%Y%m%d_%H%M%S).sql.gz

# MariaDB Backup
docker exec -t shared_mariadb mysqldump -u root -pYourPassword --all-databases | gzip > /var/www/vps-infra/volumes/backups/manual_mariadb_$(date +%Y%m%d_%H%M%S).sql.gz
```

---

## ☁️ 3. Offsite Cloud Storage Synchronization

To protect against physical VPS failure, backups can be automatically synced offsite.

### Google Drive Integration
Configure in `.env`:
```ini
GOOGLE_DRIVE_AUTH_MODE=OAuth
GOOGLE_DRIVE_FOLDER_ID=your_gdrive_folder_id
GOOGLE_DRIVE_CLIENT_ID=your_client_id
GOOGLE_DRIVE_CLIENT_SECRET=your_client_secret
```
Once configured, daily dumps are automatically mirrored to your secure Google Drive folder upon completion.

### S3 / Cloudflare R2 / MinIO Sync (Cron Option)
If using AWS S3 or Cloudflare R2, set up a cron sync using `rclone` or `aws-cli`:
```bash
# Example nightly cron job
0 3 * * * rclone sync /var/www/vps-infra/volumes/backups/ remote:my-offsite-backups/
```

---

## ♻️ 4. Restoring from a Backup File

To restore a PostgreSQL backup archive:

```bash
# 1. Unzip the backup file
gunzip -c /var/www/vps-infra/volumes/backups/backup_devops_prod_xxxx.sql.gz > /tmp/restore.sql

# 2. Feed into PostgreSQL
docker exec -i shared_postgres psql -U postgres -d devops_prod < /tmp/restore.sql

# 3. Clean up temporary uncompressed dump
rm /tmp/restore.sql
```
