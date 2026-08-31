#!/bin/bash

set -e

echo "=============================="
echo " PostgreSQL + pgAdmin Setup"
echo "=============================="

# VARIABLES
BASE_DIR="/var/www/vps-infra/volumes/db"
PG_DATA="$BASE_DIR/postgres/data"
PG_BACKUPS="$BASE_DIR/postgres/backups"
PGADMIN_DATA="$BASE_DIR/pgadmin"
PGADMIN_CONFIG="$BASE_DIR/pgadmin-config"

# Step 1: Create folders
echo "📁 Creating directories..."
mkdir -p $PG_DATA
mkdir -p $PG_BACKUPS
mkdir -p $PGADMIN_DATA/pgadmin_sessions
mkdir -p $PGADMIN_CONFIG

# Step 2: Set permissions (CRITICAL)
echo "🔐 Setting permissions..."
chown -R 5050:5050 $PGADMIN_DATA
chmod -R 700 $PGADMIN_DATA

# Step 3: Create pgAdmin config override
echo "📝 Creating pgAdmin config..."
cat <<EOF > $PGADMIN_CONFIG/config_local.py
SESSION_DB_PATH = "/var/lib/pgadmin/pgadmin_sessions"
EOF

# Step 4: Create docker-compose file
echo "📦 Creating docker-compose.yml..."
cat <<EOF > docker-compose.yml

services:
  shared_postgres:
    image: postgres:16-alpine
    container_name: shared_postgres
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: StrongPostgres@123
      POSTGRES_DB: masterdb
    command: ["postgres", "-c", "max_connections=200"]
    ports:
      - "5432:5432"
    volumes:
      - $PG_DATA:/var/lib/postgresql/data
      - $PG_BACKUPS:/backups
    networks:
      - traefik_net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: always
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL:-admin@example.com}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD:-ChangeMeToStrongPgAdminPassword123!}
      PGADMIN_CONFIG_ENHANCED_COOKIE_PROTECTION: "False"
    volumes:
      - $PGADMIN_DATA:/var/lib/pgadmin
      - $PGADMIN_CONFIG/config_local.py:/pgadmin4/config_local.py
    ports:
      - "5050:80"
    depends_on:
      - shared_postgres
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pgadmin-http.rule=Host(`${PGADMIN_HOST:-pgadmin.example.com}`)"
      - "traefik.http.routers.pgadmin-http.entrypoints=web"
      - "traefik.http.routers.pgadmin.rule=Host(`${PGADMIN_HOST:-pgadmin.example.com}`)"
      - "traefik.http.routers.pgadmin.entrypoints=websecure"
      - "traefik.http.routers.pgadmin.tls=true"
      - "traefik.http.routers.pgadmin.tls.certresolver=myresolver"
      - "traefik.http.services.pgadmin.loadbalancer.server.port=80"

networks:
  traefik_net:
    external: true
EOF

# Step 5: Start services
echo "🚀 Starting containers..."
docker compose up -d

echo ""
echo "✅ Setup completed successfully!"
echo "--------------------------------"
echo "pgAdmin: https://${PGADMIN_HOST:-pgadmin.example.com}"
echo "Postgres Port: 5432"
echo "--------------------------------"


# How to Use on New VPS
# chmod +x setup-postgres-pgadmin.sh
# ./setup-postgres-pgadmin.sh

# https://chatgpt.com/share/696e583b-8ff4-800f-887d-d7643a9b546f