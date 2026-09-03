# 🛡️ SSL Certificates & Domain Troubleshooting

Traefik v3 automatically manages Let's Encrypt TLS/SSL certificates via the HTTP-01 ACME challenge. If a domain fails to serve HTTPS or displays a certificate warning, use this runbook to resolve the issue quickly.

---

## 🔍 Common Symptoms & Fixes

### 1. "Your connection is not private" (Default Traefik Self-Signed Cert)
* **Cause**: Let's Encrypt failed to issue a certificate because the ACME HTTP-01 challenge could not reach your server on port 80.
* **Checks**:
  1. **DNS A-Record**: Verify your domain resolves directly to your VPS IP:
     ```bash
     dig +short yourdomain.com
     ```
  2. **Cloudflare Proxy Issue**: If your domain is on Cloudflare, change the DNS record from **Proxied (Orange Cloud)** to **DNS Only (Grey Cloud)**. Cloudflare's proxy blocks Let's Encrypt HTTP challenge validation if SSL is not set to "Full (Strict)".
  3. **Inspect Traefik Logs**:
     ```bash
     docker compose logs traefik | grep -i "acme"
     ```

---

### 2. "HTTP 502 Bad Gateway"
* **Cause**: Traefik is running and received the request, but the target application container is stopped or listening on a different port.
* **Fix**:
  1. Verify the container is running:
     ```bash
     docker ps | grep <your-service-name>
     ```
  2. Verify the port in your `docker-compose.yml` matches the internal container port:
     ```yaml
     # If your ASP.NET app listens on 8080, Traefik must point to 8080:
     - "traefik.http.services.my-api.loadbalancer.server.port=8080"
     ```

---

### 3. "HTTP 404 Not Found" (Traefik 404 page)
* **Cause**: Traefik has no router rule matching the incoming Host header.
* **Fix**:
  1. Check the hostname rule in your container labels:
     ```yaml
     - "traefik.http.routers.my-api.rule=Host(`api.yourdomain.com`)"
     ```
  2. Ensure the container is attached to the `traefik_net` external network:
     ```yaml
     networks:
       - traefik_net
     ```

---

## 🔄 Resetting the Let's Encrypt Certificate Cache

If a certificate was corrupted or rate-limited:

```bash
cd /var/www/vps-infra

# Stop Traefik
docker compose stop traefik

# Clear cached acme.json (backup first)
cp volumes/traefik_acme/acme.json volumes/traefik_acme/acme.json.bak
echo "{}" > volumes/traefik_acme/acme.json
chmod 600 volumes/traefik_acme/acme.json

# Restart Traefik to re-request fresh certificates
docker compose up -d traefik
```
