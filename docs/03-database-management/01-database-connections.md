# 💾 Database Management & Connection Strings

VPS-Infra includes an integrated, isolated multi-database engine suite. Microservices running on the internal `traefik_net` Docker network can communicate with databases using fast internal Docker DNS without exposing database ports to the public internet.

---

## 🔌 Connection Strings Reference

### 1. PostgreSQL 16 (Default Shared Engine)
* **Internal Docker Hostname**: `shared_postgres`
* **Port**: `5432`
* **Default Admin User**: `postgres`
* **Connection String Format**:
  ```text
  Host=shared_postgres;Port=5432;Database=<your_db>;Username=postgres;Password=<your_password>;Pooling=true;
  ```
* **URI Format**:
  ```text
  postgresql://postgres:<your_password>@shared_postgres:5432/<your_db>
  ```

### 2. Microsoft SQL Server 2022
* **Internal Docker Hostname**: `shared_sql`
* **Port**: `1433`
* **Default Admin User**: `sa`
* **Connection String Format**:
  ```text
  Server=shared_sql,1433;Database=<your_db>;User Id=sa;Password=<your_password>;TrustServerCertificate=True;
  ```

### 3. MariaDB / MySQL 11.x
* **Internal Docker Hostname**: `shared_mariadb`
* **Port**: `3306`
* **Default Admin User**: `root`
* **Connection String Format**:
  ```text
  Server=shared_mariadb;Port=3306;Database=<your_db>;Uid=root;Pwd=<your_password>;
  ```

### 4. MongoDB 7.0
* **Internal Docker Hostname**: `shared_mongodb`
* **Port**: `27017`
* **URI Format**:
  ```text
  mongodb://admin:<your_password>@shared_mongodb:27017/<your_db>?authSource=admin
  ```

---

## 🛠️ Managing Database Engines via CLI

Use the built-in management script to start, stop, or check database engine health:

```bash
cd /var/www/vps-infra

# Check status of all engines
./db/manage-databases.sh status

# Start a specific database
./db/manage-databases.sh start postgres
./db/manage-databases.sh start mssql
./db/manage-databases.sh start mariadb
./db/manage-databases.sh start mongodb

# Stop an idle engine to conserve RAM
./db/manage-databases.sh stop oracle
```

---

## 🛡️ External Connection Security

By default, database ports (`5432`, `1433`, `3306`, `27017`) are **not** bound to public IP addresses to protect against automated brute-force attacks.

To connect from your local development machine (e.g. pgAdmin, DBeaver, or SQL Server Management Studio), use an **SSH Tunnel**:

```bash
# Example SSH Tunnel for PostgreSQL (maps local port 54320 to VPS internal 5432)
ssh -L 54320:localhost:5432 root@your-vps-ip
```
Then connect DBeaver or pgAdmin to `localhost:54320`.
