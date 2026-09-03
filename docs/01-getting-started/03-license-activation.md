# 🔑 Enterprise License Activation Guide

VPS-Infra enforces subscription verification. The platform natively supports two licensing deployment tracks depending on your infrastructure topology:

```text
+-----------------------------------------------------------------------------------+
|                        CHOOSE YOUR DEPLOYMENT TRACK                               |
+-----------------------------------------------------------------------------------+
| ☁️ Track 1: Cloud-Flex Mode (Recommended for Cloud VPS)                           |
|    - For AWS, Azure, DigitalOcean, Hetzner, Hostinger, GCP, or any virtual host.  |
|    - No hardware fingerprint needed.                                              |
|    - Zero downtime during VPS plan resize or snapshot migration.                  |
+-----------------------------------------------------------------------------------+
| 🔒 Track 2: Hardware-Locked Mode (Dedicated On-Premise Servers)                   |
|    - For bare-metal dedicated servers requiring strict physical node security.    |
|    - Bound to server hardware fingerprint.                                        |
+-----------------------------------------------------------------------------------+
```

---

## ☁️ Track 1: Cloud-Flex Mode (Cloud VPS)

### Step 1: Request Your Cloud-Flex Token
Send an email to `licensing@tmkcomputers.in` or your dedicated account manager:

```text
To: licensing@tmkcomputers.in
Subject: License Request: Cloud-Flex - [Your Company Name]

- Client / Company Name: Your Company Name
- Mode: Cloud-Flex (Cloud VPS)
- Plan Tier: Enterprise
- Duration: 1 Year (365 Days)
```

*(Note: In Cloud-Flex mode, you do **not** need to extract or provide any hardware fingerprint!)*

### Step 2: Activate Your License
Once you receive your signed token, run the 1-click activator:

**On Linux VPS**:
```bash
cd /var/www/vps-infra
./activate-license.sh "YOUR_SIGNED_TMK_LICENSE_KEY"
```

---

## 🔒 Track 2: Hardware-Locked Mode (Dedicated On-Premise)

### Step 1: Extract Server Hardware Fingerprint

**On Linux Host**:
```bash
echo -n "TMK-HW-$(cat /etc/machine-id)" | sha256sum | awk '{print $1}'
```
*Example Output: `b9e4ee73b6b7a63023c8c2c6eb47f71f265d930533b336b6daa5e6f46299c39f`*


### Step 2: Send Fingerprint to Licensing Team
Send your 64-character fingerprint to `licensing@tmkcomputers.in`:

```text
To: licensing@tmkcomputers.in
Subject: License Request: Hardware-Locked - [Your Company Name]

- Client / Company Name: Your Company Name
- Mode: Hardware-Locked
- Hardware Fingerprint: <Paste your 64-character fingerprint here>
- Plan Tier: Enterprise
- Duration: 1 Year
```

### Step 3: Activate License
Activate using the same 1-click CLI script as shown in Track 1 above.

---

## 🖥️ Alternative: Live Activation via Web UI

If you prefer using the graphical interface:
1. Open your browser and navigate to `https://devops.yourdomain.com`.
2. If the platform is unlicensed, an activation lock modal will appear.
3. Paste your signed token into the license key input field.
4. Click **"Activate License"**. The platform unlocks instantly without requiring a container restart.

---

## 🔍 Verifying License Status

You can check your active subscription status anytime:

```bash
# Via CLI command on server:
curl -s http://localhost:8080/api/License/status | jq .
```

Expected output:
```json
{
  "isValid": true,
  "clientName": "Your Company Name",
  "plan": "Enterprise",
  "daysRemaining": 365,
  "maxProjects": 100,
  "maxServices": 500
}
```

Next Step: Ready to deploy applications? Proceed to [📦 Deploying Web APIs](02-deploying-applications/01-web-apis.md).
