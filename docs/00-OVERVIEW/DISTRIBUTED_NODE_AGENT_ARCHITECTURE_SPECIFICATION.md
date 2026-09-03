# 🛰️ Tier 1 Architecture Specification: Distributed `vps-infra-agent`

## Executive Summary

This document specifies the technical architecture, communication protocol, security model, and implementation blueprint for **Tier 1: The Distributed `vps-infra-agent`**.

By introducing this lightweight agent, the **VPS-Infra** platform evolves from managing a **single host** to managing a **globally distributed fleet of Linux and Windows servers** across any cloud provider (Hostinger, AWS, Azure, DigitalOcean, Hetzner) or on-premise enterprise datacenter.

---

## 🏛️ 1. Distributed Fleet Topology

```text
+===================================================================================================+
|                                    VPS-INFRA CENTRAL CONTROL PLANE                                |
|                                   (Master Node / Cloud Orchestrator)                              |
|                                                                                                   |
|  * DevOps Manager API (.NET 10)                  * React Management Web Portal                    |
|  * CI Pipeline Engine & Job Dispatcher           * PostgreSQL System Database (Fleet Meta)        |
|  * Central License Server (HMAC-SHA256)          * WebSocket Gateway (wss://control.domain.com)   |
+===================================================================================================+
                                                  |
                                                  | Outbound-Only Persistent WebSocket / gRPC (TLS)
                                                  | (Zero inbound ports required on worker nodes)
                         +------------------------+------------------------+
                         |                                                 |
                         v                                                 v
+---------------------------------------------------+   +---------------------------------------+
|             REMOTE WORKER NODE 1                  |   |          REMOTE WORKER NODE 2         |
|         (Hostinger Cloud Linux VPS)               |   |        (Enterprise Windows Server)    |
|---------------------------------------------------|   |---------------------------------------|
|  * vps-infra-agent (Linux systemd service)        |   |  * vps-infra-agent.exe (Win Service)  |
|  * Docker Engine / Docker Compose                 |   |  * Docker Engine + Host IIS / .NET 4.8|
|  * Local Traefik Edge (Public HTTPS Entrypoint)   |   |  * Local Traefik Edge (Loopback IIS)  |
|  * Tenant Containers:                             |   |  * Tenant Workloads:                  |
|      - microservice-api-prod                      |   |      - modern-docker-api-prod         |
|      - frontend-react-prod                        |   |      - legacy-aspnet-app (Host IIS)   |
|      - shared_postgres_node1                      |   |      - Native Windows Background Svc  |
+---------------------------------------------------+   +---------------------------------------+
```

---

## 🔌 2. Outbound-Only Connection Model (Firewall & NAT Traversal)

The agent connects **outward** to the Central Control Plane.

```text
+-----------------------+                         +-----------------------+
|   Remote Worker Node  |                         | Central Control Plane |
|   (vps-infra-agent)   |                         |     (devops-api)      |
+-----------------------+                         +-----------------------+
            |                                                 |
            | 1. Outbound TLS Handshake (Port 443)            |
            |------------------------------------------------>|
            |                                                 |
            | 2. Authenticate: Authorization: Bearer <TOKEN>  |
            |------------------------------------------------>|
            |                                                 |
            | 3. HTTP 101 Switching Protocols to WebSocket    |
            |<------------------------------------------------|
            |                                                 |
            |=================================================|
            |     SECURE DUPLEX WEBSOCKET TUNNEL (ESTABLISHED)|
            |=================================================|
            |                                                 |
            | 4. Node Handshake: CPU, RAM, Disk, OS, Docker   |
            |------------------------------------------------>| (Node status -> "ONLINE")
            |                                                 |
            | 5. Periodic Heartbeat & Telemetry (Every 30s)   |
            |------------------------------------------------>|
            |                                                 |
            | 6. DISPATCH_BUILD_JOB (Control Plane pushes job)|
            |<------------------------------------------------|
            |                                                 |
            | 7. Stream Real-time Build Logs (Chunk by chunk) |
            |------------------------------------------------>| (Rendered live in UI)
            |                                                 |
            | 8. JOB_COMPLETED (Exit Code, Artifact Manifest) |
            |------------------------------------------------>| (Deployment finalized)
```

### Why Outbound-Only?
1. **Zero Open Inbound Ports**: The worker server does not need port 22 (SSH) or any custom management port exposed to the public internet.
2. **Works Behind Corporate Firewalls & NAT**: Dedicated on-premise Windows servers behind strict enterprise firewalls can connect seamlessly.
3. **Dynamic IP Tolerant**: If a cloud VPS changes its public IP during resize, the agent reconnects automatically.

---

## ⚡ 3. 1-Click Zero-Touch Node Pairing Workflow

Adding a new server to the fleet requires running a single command.

```text
[ DevOps Admin in Web UI ]
            |
            v
1. Clicks "Add Node" -> Types name: "Mumbai-Prod-01" -> Selects OS & Tags
            |
            v
2. DevOps API generates a one-time enrollment token (JWT signed, valid for 15 mins)
            |
            v
3. Web UI presents ready-to-run 1-click command:
```

### For Linux Worker Nodes (Ubuntu / Debian / RHEL):
```bash
curl -fsSL https://control.yourdomain.com/install-agent.sh | sudo bash -s -- \
  --server "https://control.yourdomain.com" \
  --token "tmk_node_enroll_9f83acb1847e2a9" \
  --name "Mumbai-Prod-01" \
  --tags "prod,linux,mumbai"
```

### For Windows Worker Nodes (PowerShell as Administrator):
```powershell
irm https://control.yourdomain.com/install-agent.ps1 | iex; `
  Install-VpsInfraAgent `
    -Server "https://control.yourdomain.com" `
    -Token "tmk_node_enroll_9f83acb1847e2a9" `
    -Name "Windows-OnPrem-01" `
    -Tags "prod,windows,iis"
```

### What the Install Script Automates:
1. Downloads the OS-specific single-binary `vps-infra-agent` (~18MB, zero runtime dependencies).
2. Verifies Docker Engine / Docker Compose presence (installs if missing on Linux).
3. Creates directory structure (`/var/www/vps-infra` or `C:\vps-infra`).
4. Generates an encrypted local keypair and exchanges it for a permanent node certificate.
5. Installs and starts the service:
   - **Linux**: Configures `systemd` service (`/etc/systemd/system/vps-infra-agent.service`).
   - **Windows**: Configures Windows Service via `New-Service` or NSSM.
6. The node immediately appears **ONLINE** in the DevOps Manager dashboard.

---

## 🗄️ 4. Database Schema Extensions (Control Plane)

To track distributed nodes and assign workloads, two new tables and schema updates are added to `devops_prod`:

```sql
-- 1. Fleet Worker Nodes
CREATE TABLE "Nodes" (
    "Id" VARCHAR(64) PRIMARY KEY,
    "Name" VARCHAR(128) NOT NULL,
    "OperatingSystem" VARCHAR(32) NOT NULL, -- 'Linux', 'Windows'
    "Architecture" VARCHAR(32) NOT NULL,    -- 'x86_64', 'arm64'
    "AgentVersion" VARCHAR(32) NOT NULL,
    "PublicIp" VARCHAR(64),
    "PrivateIp" VARCHAR(64),
    "Status" VARCHAR(32) DEFAULT 'OFFLINE',  -- 'ONLINE', 'OFFLINE', 'BUSY', 'MAINTENANCE'
    "Tags" TEXT[],                          -- ['production', 'mumbai', 'docker', 'iis']
    "TotalCpuCores" INT NOT NULL DEFAULT 1,
    "TotalMemoryBytes" BIGINT NOT NULL DEFAULT 0,
    "TotalDiskBytes" BIGINT NOT NULL DEFAULT 0,
    "UsedCpuPercent" NUMERIC(5,2) DEFAULT 0.0,
    "UsedMemoryPercent" NUMERIC(5,2) DEFAULT 0.0,
    "UsedDiskPercent" NUMERIC(5,2) DEFAULT 0.0,
    "ActiveContainersCount" INT DEFAULT 0,
    "LastHeartbeatUtc" TIMESTAMP WITH TIME ZONE,
    "HardwareFingerprint" VARCHAR(128),
    "NodeAuthTokenHash" VARCHAR(256) NOT NULL,
    "CreatedAtUtc" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    "UpdatedAtUtc" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Fleet Node Events & Audit Log
CREATE TABLE "NodeLogs" (
    "Id" BIGSERIAL PRIMARY KEY,
    "NodeId" VARCHAR(64) REFERENCES "Nodes"("Id") ON DELETE CASCADE,
    "EventType" VARCHAR(64) NOT NULL,        -- 'CONNECTED', 'DISCONNECTED', 'JOB_STARTED', 'JOB_FAILED'
    "Message" TEXT NOT NULL,
    "PayloadJson" JSONB,
    "TimestampUtc" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Project Services: Node Target Binding
ALTER TABLE "ProjectServices" 
ADD COLUMN "TargetNodeId" VARCHAR(64) REFERENCES "Nodes"("Id") ON DELETE SET NULL,
ADD COLUMN "NodeSelectorTags" TEXT[];       -- e.g. ['prod', 'linux'] if dynamically scheduled
```

---

## 📡 5. WebSocket Wire Protocol Specification

The protocol uses structured JSON envelopes over WebSocket text frames:

```json
{
  "id": "msg_01J8F...",
  "type": "MESSAGE_TYPE",
  "timestamp": "2026-09-03T18:00:00.000Z",
  "payload": {}
}
```

### Message Types Catalog

| Message Type | Direction | Description |
|---|:---:|---|
| `NODE_HELLO` | Agent -> Control | Initial handshake with hardware specs and installed runtimes. |
| `NODE_HEARTBEAT` | Agent -> Control | 30s telemetry: CPU %, RAM %, Disk %, Container count. |
| `DISPATCH_JOB` | Control -> Agent | Dispatches a build, test, deploy, or restart task to the node. |
| `JOB_OUTPUT_CHUNK` | Agent -> Control | Real-time terminal output stream (stdout/stderr). |
| `JOB_COMPLETED` | Agent -> Control | Signals job completion with exit code and summary. |
| `CONTAINER_ACTION` | Control -> Agent | Start, Stop, Restart, or View Logs of a container. |
| `AGENT_UPGRADE` | Control -> Agent | Triggers self-upgrade of the agent binary. |

### Example: `DISPATCH_JOB` Payload
```json
{
  "id": "job_99812",
  "type": "DISPATCH_JOB",
  "payload": {
    "jobId": "build_4812",
    "projectServiceId": "svc_bank_mitra_api",
    "workloadType": "DOCKER_COMPOSE",
    "git": {
      "repoUrl": "https://github.com/client/bank-mitra-api.git",
      "branch": "main",
      "commitSha": "a1b2c3d4",
      "accessToken": "ghp_secureTokenMasked"
    },
    "environment": "Prod",
    "composeFileContent": "services:\n  api:\n    image: bank-mitra-api:latest\n...",
    "envVariables": {
      "ASPNETCORE_ENVIRONMENT": "Production",
      "PORT": "8080"
    }
  }
}
```

---

## 💻 6. Agent Architecture & Internals

The agent is implemented as a single self-contained binary written in Go or .NET AOT:

```text
+-------------------------------------------------------------------------------+
|                             vps-infra-agent BINARY                            |
|                                                                               |
|  +-------------------------------------------------------------------------+  |
|  |                   Connection & Security Manager                         |  |
|  |  * Persistent WebSocket Client (Auto-reconnect with exponential backoff)|  |
|  |  * TLS Mutual Auth / Token Rotation                                     |  |
|  +-------------------------------------------------------------------------+  |
|                                      |                                        |
|         +----------------------------+----------------------------+           |
|         |                                                         |           |
|         v                                                         v           |
|  +-----------------------------+           +-------------------------------+  |
|  |   System Telemetry Engine   |           |     Job Execution Engine      |  |
|  |  * CPU & RAM Profiler       |           |  * Git Cloner & Workspace Mgr |  |
|  |  * Disk Usage Monitor       |           |  * Docker Engine Controller   |  |
|  |  * Local Container Lister   |           |  * Host IIS / PowerShell Exec |  |
|  |  * Hardware Fingerprint     |           |  * Process Output Streamer    |  |
|  +-----------------------------+           +-------------------------------+  |
+-------------------------------------------------------------------------------+
```

### Core Execution Modules:

1. **Docker Engine Subsystem**:
   - Connects directly to the local Docker daemon:
     - Linux: `/var/run/docker.sock`
     - Windows: `//./pipe/docker_engine`
   - Executes image builds, container lifecycle changes (`docker compose up -d`), and volume management.

2. **Windows Legacy Subsystem** *(Active only on Windows OS)*:
   - Interacts with Microsoft IIS via PowerShell `WebAdministration` module.
   - Executes MSBuild, stops/starts Application Pools, and updates virtual directories.

3. **Streamer Engine**:
   - Buffers stdout/stderr from subprocesses and flushes chunks every 100ms over WebSocket to ensure smooth terminal rendering without flooding the connection.

---

## 🚀 7. Step-by-Step Implementation Roadmap

```text
+-----------------------------------------------------------------------------------------+
| PHASE 1: Control Plane Fleet Management APIs (devops-manager)                           |
| • Create "Nodes" & "NodeLogs" database migrations.                                      |
| • Add Fleet Management endpoints:                                                       |
|     - POST /api/nodes/enroll (Generate 1-click token)                                   |
|     - GET  /api/nodes        (List fleet nodes, specs, status)                          |
|     - GET  /api/nodes/{id}   (Live node telemetry)                                      |
| • Build Fleet Management UI in DevOps Manager Web Portal.                               |
+-----------------------------------------------------------------------------------------+
                                             |
                                             v
+-----------------------------------------------------------------------------------------+
| PHASE 2: Control Plane WebSocket Dispatcher Gateway                                     |
| • Implement WebSocket hub (/ws/agent) in devops-api.                                    |
| • Add token authentication and node state lifecycle manager.                            |
| • Adapt CI build-runner.js: When project targets remote node, route job to WebSocket.   |
+-----------------------------------------------------------------------------------------+
                                             |
                                             v
+-----------------------------------------------------------------------------------------+
| PHASE 3: vps-infra-agent Binary Core                                                    |
| • Build single-binary agent (Go or .NET AOT cross-compiled for Linux x64/arm64 & Win).  |
| • Implement WebSocket client with auto-reconnect and heartbeat loop.                   |
| • Implement Git + Docker execution modules.                                             |
| • Implement Windows IIS execution module.                                               |
+-----------------------------------------------------------------------------------------+
                                             |
                                             v
+-----------------------------------------------------------------------------------------+
| PHASE 4: 1-Click Bootstrap Installers & Field Testing                                   |
| • Publish install-agent.sh (Linux) and install-agent.ps1 (Windows).                     |
| • Test multi-node deployment: Control Plane on Hostinger VPS dispatching jobs to both:  |
|     1. Remote Hostinger Linux VPS                                                       |
|     2. Remote Windows Server 2022                                                       |
+-----------------------------------------------------------------------------------------+
```

---

## 🏆 Key Advantages of This Design

1. **Massive Cloud Agility**: Your clients can mix and match providers at will. They can run their database on a high-memory Hetzner VPS ($15/mo), web APIs on Hostinger VPS ($7/mo), and legacy ERP on an on-premise Windows Server—all controlled from **one unified dashboard**.
2. **Zero Inbound Attack Surface**: Because worker nodes only make outbound connections, they are completely invisible to automated port scanners and botnets on the internet.
3. **Seamless Monetization**: Your central licensing server can enforce tiered subscriptions based on node count (e.g. *Starter: 1 Node*, *Professional: 5 Nodes*, *Enterprise: Unlimited Nodes*).
