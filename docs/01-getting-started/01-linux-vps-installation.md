# 🚀 Linux VPS Quickstart Installation Guide

This guide walks you through bootstrapping your **VPS-Infra** platform on a Linux VPS (such as Hostinger, DigitalOcean, Hetzner, AWS EC2, or Linode) running Ubuntu 22.04 or 24.04 LTS.

---

## 💻 Hardware & System Prerequisites

| Specification | Minimum | Recommended Production |
|---|---|---|
| **Operating System** | Ubuntu 22.04 / 24.04 LTS | Ubuntu 24.04 LTS (x86_64) |
| **vCPU** | 2 vCPUs | 4+ vCPUs |
| **RAM** | 4 GB | 8 GB – 16 GB |
| **Storage** | 40 GB NVMe / SSD | 100 GB+ NVMe SSD |
| **Docker Engine** | Docker v24.0+ | Docker v26.0+ & Compose v2 |
| **Open Firewall Ports** | `80/tcp`, `443/tcp` | `80/tcp`, `443/tcp` |

---

## 🌐 1. DNS A-Record Configuration

Before running the installer, point the following **DNS A-Records** to your VPS Public IP address (e.g. `195.35.x.x`) with your DNS provider (Cloudflare, GoDaddy, Route53):

| Subdomain | Target Example | Description |
|---|---|---|
| `@` / `yourdomain.com` | `yourdomain.com` | Primary Gateway |
| `devops` | `devops.yourdomain.com` | DevOps Manager Web UI |
| `devops-api` | `devops-api.yourdomain.com` | DevOps Backend API |
| `ci` | `ci.yourdomain.com` | CI/CD Dashboard |
| `ci-api` | `ci-api.yourdomain.com` | CI/CD Pipeline Engine |
| `registry` | `registry.yourdomain.com` | Private Docker Registry |
| `traefik` | `traefik.yourdomain.com` | Traefik Router Dashboard |

> **Cloudflare Tip**: If using Cloudflare DNS, set the proxy status to **DNS Only (Grey Cloud)** during initial Let's Encrypt certificate issuance.

---

## 📥 2. Clone the Platform Runtime

SSH into your Linux VPS and clone the client repository to `/var/www/vps-infra`:

```bash
# Create target directory and clone
sudo mkdir -p /var/www/vps-infra
sudo chown -R $USER:$USER /var/www/vps-infra
git clone https://github.com/tmk-computers/vps-infra-client.git /var/www/vps-infra
cd /var/www/vps-infra
```

---

## ⚙️ 3. Configure Environment Variables (`.env`)

Copy the example environment template and configure your domain and credentials:

```bash
cp .env.example .env
nano .env
```

### Essential Settings to Update:
```ini
# ------------------------------------------------------------
# Primary Domain & SSL Contact
# ------------------------------------------------------------
PRIMARY_DOMAIN=yourdomain.com
ACME_SSL_EMAIL=admin@yourdomain.com
COMPANY_NAME="Your Company Name"

# ------------------------------------------------------------
# Initial SuperAdmin Credentials
# ------------------------------------------------------------
SUPERADMIN_EMAIL=admin@yourdomain.com
SUPERADMIN_PASSWORD=YourStrongPassword123!
SUPERADMIN_FULLNAME="Super Admin"

# ------------------------------------------------------------
# Shared Database Master Password
# ------------------------------------------------------------
POSTGRES_PASSWORD=YourSuperSecurePostgresPassword123!
```

Save and exit (`Ctrl + O`, `Enter`, `Ctrl + X`).

---

## 🚀 4. Run 1-Click Bootstrap Installation

Run the bootstrap installer to initialize Docker networks, configure volumes, and launch the platform:

```bash
chmod +x setup.sh
./setup.sh
```

### With Pre-Issued License Token:
If you already received your enterprise license token, activate it during setup:
```bash
./setup.sh --license "YOUR_SIGNED_TMK_LICENSE_KEY"
```

---

## ✅ 5. Verification & Live Dashboard Access

Once the containers are up, check their status:

```bash
docker compose ps
```

Visit the following URLs in your browser:
* **DevOps Manager UI**: `https://devops.yourdomain.com`
* **CI/CD Dashboard**: `https://ci.yourdomain.com`
* **Traefik Edge Routing**: `https://traefik.yourdomain.com`

Log in using your `SUPERADMIN_EMAIL` and `SUPERADMIN_PASSWORD`.

Next Step: If you have not activated your license yet, proceed to [🔑 License Activation Guide](03-license-activation.md).
