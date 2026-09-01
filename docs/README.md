# 📖 VPS-Infra Client Documentation Hub

Welcome to the **VPS-Infra** customer documentation center. This repository contains complete deployment guides, onboarding instructions, multi-framework deployment runbooks, operations manuals, and API integration guides for your VPS-Infra platform.

---

## 🧭 Navigation Matrix by Category

```
                                  [ VPS-INFRA DOCUMENTATION HUB ]
                                                 │
         ┌──────────────────┬───────────────────┼───────────────────┬──────────────────┐
         ▼                  ▼                   ▼                   ▼                  ▼
   [ ARCHITECTURE ]   [ ONBOARDING ]      [ DEVELOPERS ]      [ OPERATIONS ]     [ AI AGENTS ]
     & TOPOLOGY          & SETUP            & TECH LEADS         & DEVOPS          & MLOPS
         │                  │                   │                   │                  │
    00-OVERVIEW/     01-ONBOARDING/      02-DEV-GUIDES/       03-OPERATIONS/       04-AI/
```

---

### 📂 00. Platform Overview & Architecture
High-level runtime architecture, features, and platform capabilities.

| Document | Description |
|---|---|
| [`00-OVERVIEW/SYSTEM_RUNTIME_TOPOLOGY.md`](./00-OVERVIEW/SYSTEM_RUNTIME_TOPOLOGY.md) | Platform runtime architecture, container topology, Traefik edge routing, and storage volumes. |
| [`00-OVERVIEW/PRODUCT_BUSINESS_GUIDE.md`](./00-OVERVIEW/PRODUCT_BUSINESS_GUIDE.md) | Product capabilities, feature matrix, and business value propositions. |
| [`00-OVERVIEW/PRODUCT_TECHNICAL_GUIDE.md`](./00-OVERVIEW/PRODUCT_TECHNICAL_GUIDE.md) | Technical guide covering Traefik routing, reverse proxy, and multi-database connectivity. |
| [`00-OVERVIEW/POSTER_1_VPS_INFRA_CORE_BENEFITS.md`](./00-OVERVIEW/POSTER_1_VPS_INFRA_CORE_BENEFITS.md) | Visual summary poster of VPS-Infra core capabilities and infrastructure benefits. |
| [`00-OVERVIEW/POSTER_2_AI_NATIVE_DEVOPS_PLATFORM_BENEFITS.md`](./00-OVERVIEW/POSTER_2_AI_NATIVE_DEVOPS_PLATFORM_BENEFITS.md) | Visual summary poster of AI-Native DevOps capabilities. |

---

### 📂 01. Client Onboarding & Runbooks
Everything needed to bootstrap your VPS, activate your subscription license, and deploy application templates.

| Document | Description |
|---|---|
| [`01-WHITE-LABEL-CLIENT-ONBOARDING/CLIENT_ONBOARDING_GUIDE.md`](./01-WHITE-LABEL-CLIENT-ONBOARDING/CLIENT_ONBOARDING_GUIDE.md) | Complete onboarding guide: user provisioning, microservice onboarding, push-to-deploy webhooks, and database connections. |
| [`01-WHITE-LABEL-CLIENT-ONBOARDING/CLIENT_DEVOPS_GUIDE.md`](./01-WHITE-LABEL-CLIENT-ONBOARDING/CLIENT_DEVOPS_GUIDE.md) | Production installation, DNS configuration, Cloud-Flex & Hardware license activation, and backup operations. |
| [`01-WHITE-LABEL-CLIENT-ONBOARDING/FRAMEWORK_TEMPLATES_GUIDE.md`](./01-WHITE-LABEL-CLIENT-ONBOARDING/FRAMEWORK_TEMPLATES_GUIDE.md) | Deployment templates and Dockerfiles for Node.js, Spring Boot, Laravel, FastAPI, Express.js, React, and Angular. |

---

### 📂 02. Developer & Project Build Guides
Development standards, CLI usage, mobile APK distribution pipelines, and legacy migration guides.

| Document | Description |
|---|---|
| [`02-DEVELOPER-AND-PROJECT-GUIDES/CLI_REFERENCE_GUIDE.md`](./02-DEVELOPER-AND-PROJECT-GUIDES/CLI_REFERENCE_GUIDE.md) | Complete CLI reference for maintenance, container management, and database operations. |
| [`02-DEVELOPER-AND-PROJECT-GUIDES/FLUTTER_APK_BUILD_PIPELINE.md`](./02-DEVELOPER-AND-PROJECT-GUIDES/FLUTTER_APK_BUILD_PIPELINE.md) | Automated Flutter Android APK build and publishing pipeline. |
| [`02-DEVELOPER-AND-PROJECT-GUIDES/NATIVE_ANDROID_APK_BUILD_PIPELINE.md`](./02-DEVELOPER-AND-PROJECT-GUIDES/NATIVE_ANDROID_APK_BUILD_PIPELINE.md) | Native Gradle-based Android APK build matrix and artifacts delivery. |
| [`02-DEVELOPER-AND-PROJECT-GUIDES/REACT_NATIVE_APK_BUILD_PIPELINE.md`](./02-DEVELOPER-AND-PROJECT-GUIDES/REACT_NATIVE_APK_BUILD_PIPELINE.md) | React Native Android build pipeline configuration. |
| [`02-DEVELOPER-AND-PROJECT-GUIDES/MIGRATION_GUIDE_NATIVE_ANDROID_TO_VPS_INFRA_CI_PIPELINE.md`](./02-DEVELOPER-AND-PROJECT-GUIDES/MIGRATION_GUIDE_NATIVE_ANDROID_TO_VPS_INFRA_CI_PIPELINE.md) | Migration guide for legacy Android apps to VPS-Infra CI. |
| [`02-DEVELOPER-AND-PROJECT-GUIDES/MIGRATION_GUIDE_WINDOWS_IIS_TO_LINUX_DOCKER_NETCORE_API.md`](./02-DEVELOPER-AND-PROJECT-GUIDES/MIGRATION_GUIDE_WINDOWS_IIS_TO_LINUX_DOCKER_NETCORE_API.md) | Guide to migrating Windows IIS .NET APIs to Linux Docker containers. |
| [`02-DEVELOPER-AND-PROJECT-GUIDES/MIGRATION_GUIDE_WINDOWS_IIS_TO_LINUX_DOCKER_ANGULAR_WEB.md`](./02-DEVELOPER-AND-PROJECT-GUIDES/MIGRATION_GUIDE_WINDOWS_IIS_TO_LINUX_DOCKER_ANGULAR_WEB.md) | Guide to migrating Windows IIS Angular applications to Nginx Docker containers. |

---

### 📂 03. Operations & Maintenance
Client-side operational runbooks, backups, disaster recovery, and storage maintenance.

| Document | Description |
|---|---|
| [`03-OPERATIONS-AND-DEVOPS/DISASTER_RECOVERY_PLAYBOOK.md`](./03-OPERATIONS-AND-DEVOPS/DISASTER_RECOVERY_PLAYBOOK.md) | Automated database backup scheduling, S3/Google Drive synchronization, and disaster recovery procedures. |
| [`03-OPERATIONS-AND-DEVOPS/STORAGE_LOGGING_CLEANUP_GUIDE.md`](./03-OPERATIONS-AND-DEVOPS/STORAGE_LOGGING_CLEANUP_GUIDE.md) | Log rotation policies, Docker prune automation, and disk capacity maintenance. |

---

### 📂 04. AI-Native & Agent Integration
Guides for deploying AI applications and integrating autonomous coding agents.

| Document | Description |
|---|---|
| [`04-AI-NATIVE-AND-AGENTS/AI_NATIVE_APPS_AND_AGENTS_INFRASTRUCTURE_GUIDE.md`](./04-AI-NATIVE-AND-AGENTS/AI_NATIVE_APPS_AND_AGENTS_INFRASTRUCTURE_GUIDE.md) | Deploying LangChain, LlamaIndex, Ollama, and vector databases on VPS-Infra. |
| [`04-AI-NATIVE-AND-AGENTS/AI_NATIVE_DEVOPS_MLOPS_FINAL_ARCHITECTURE_BLUEPRINT.md`](./04-AI-NATIVE-AND-AGENTS/AI_NATIVE_DEVOPS_MLOPS_FINAL_ARCHITECTURE_BLUEPRINT.md) | Architecture blueprint for AI DevOps and model serving workloads. |
| [`04-AI-NATIVE-AND-AGENTS/POLYGLOT_CUSTOMER_AGENT_INTEGRATION_GUIDE.md`](./04-AI-NATIVE-AND-AGENTS/POLYGLOT_CUSTOMER_AGENT_INTEGRATION_GUIDE.md) | Integrating external AI agents via webhook APIs and token authentication. |
