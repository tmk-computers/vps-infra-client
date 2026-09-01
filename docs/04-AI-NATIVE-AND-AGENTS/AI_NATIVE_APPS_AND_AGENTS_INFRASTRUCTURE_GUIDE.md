# 🤖 AI-Native Apps & AI Agents Infrastructure Guide for Startups

> **Document Version**: 1.0.0  
> **Status**: Approved Architecture Specification  
> **Target Audience**: Startups, Engineering Leaders, AI Developers, DevOps Architects  
> **Core Objective**: Explain how `vps-infra` enables startups to build AI-Native apps and AI Agents by handling all underlying AI infrastructure dependencies while startups focus 100% on their business logic.

---

## 1. What Actually Is an AI Agent? (In Simple DevOps Terms)

Traditional software executes fixed procedural `if/else` code. An **AI Agent** is an autonomous software system where a Large Language Model (LLM) acts as the **decision-making engine** inside a state loop:

```mermaid
graph LR
    subgraph AgentLoop ["Agent Lifecycle"]
        Input["User Request / Webhook"] --> Brain["LLM (Reasoning Engine)"]
        Brain --> Decision{"Need to take action?"}
        Decision -->|"Yes"| Tool["Execute Tool (API, SQL, Docker)"]
        Tool --> Observation["Return Tool Output"]
        Observation --> Brain
        Decision -->|"No / Completed"| Response["Final Answer / Action Taken"]
    end
```

### The 4 Core Building Blocks of Every AI Agent:
1. **The Brain (Model)**: The LLM (e.g., Llama-3.2, DeepSeek-R1, GPT-4o, Claude 3.5 Sonnet) that interprets intent, breaks goals into sub-tasks, and decides which tool to call.
2. **Memory & Context**:
   - *Short-term memory*: Conversation history and current step state (stored in Redis / PostgreSQL).
   - *Long-term memory*: Past documents, runbooks, and vector embeddings (stored in PostgreSQL `pgvector` / Qdrant).
3. **Tools & Action Engine**: APIs, bash scripts, database query runners, or web scrapers that the agent executes to interact with the real world.
4. **Guardrails & State Machine**: Deterministic rules that prevent the agent from looping infinitely, exceeding budgets, or executing destructive mistakes.

---

## 2. Hardware Capability Matrix: What AI Apps Can Run on Which VPS?

```mermaid
graph TD
    subgraph Tier1 ["1. 4 vCPU / 16 GB RAM / 200 GB Disk ($15 - $30/mo)"]
        T1_1["AI RAG APIs (FastAPI + pgvector)"]
        T1_2["Small Quantized Local Models (1B - 3B via Ollama CPU)"]
        T1_3["Cloud-Model Agents (Orchestrating OpenAI / Claude / DeepSeek)"]
        T1_4["Document Ingestion & Embedding Pipelines"]
    end

    subgraph Tier2 ["2. 8 vCPU / 32 GB RAM / 400 GB Disk ($40 - $80/mo)"]
        T2_1["Medium Quantized Local Models (7B - 8B via Ollama / llama.cpp CPU)"]
        T2_2["Self-Hosted Vector DB Cluster (Qdrant / pgvector)"]
        T2_3["Autonomous Multi-Agent Systems (LangGraph / CrewAI)"]
        T2_4["Batch Document & Dataset Embedding Workers"]
    end

    subgraph Tier3 ["3. Dedicated GPU VPS (16GB-24GB VRAM: $150 - $350/mo)"]
        T3_1["High-Throughput Local Inference (vLLM / TensorRT: 7B - 14B models)"]
        T3_2["Real-Time Token Streaming (50+ tokens/sec for 100+ users)"]
        T3_3["Private Fine-Tuned Models (LoRA / QLoRA)"]
        T3_4["Zero-Data-Egress Private Cloud AI (No external API costs)"]
    end
```

### Detailed VPS Hardware Capacity & Market Pricing Breakdown:

| VPS Tier & Hardware | Estimated Market Pricing | Supported Local Models (CPU/GPU) | Supported AI Workloads | Maximum Concurrency & Performance |
| :--- | :--- | :--- | :--- | :--- |
| **4 vCPU / 16 GB RAM**<br/>(Standard VPS) | **$15 – $30 / mo**<br/>*(Hetzner, DigitalOcean, Contabo)* | • `llama3.2:1b` (1.3 GB RAM)<br/>• `llama3.2:3b` (2.5 GB RAM)<br/>• `deepseek-r1:1.5b` (1.5 GB RAM)<br/>• `nomic-embed-text` (0.6 GB RAM) | • **Agent Orchestrators** calling Cloud APIs (OpenAI, Anthropic, DeepSeek).<br/>• **RAG Applications** with PostgreSQL `pgvector`.<br/>• **Small Local AI Tasks**: Text extraction, classification on CPU. | 5–15 simultaneous RAG queries / sec.<br/>Local model latency: ~15–25 tokens/sec (CPU). |
| **8 vCPU / 32 GB RAM**<br/>(Standard VPS) | **$40 – $80 / mo**<br/>*(Hetzner, DigitalOcean, Contabo)* | • `llama3.1:8b` (4-bit: 5.5 GB RAM)<br/>• `mistral:7b` (4-bit: 5.1 GB RAM)<br/>• `deepseek-r1:7b` (4-bit: 5.5 GB RAM)<br/>• Embedding models | • **Full Multi-Agent Systems** (Supervisor + 4 Sub-agents).<br/>• **Autonomous SRE / AutoOps agents** reading logs and analyzing telemetry.<br/>• **Self-hosted RAG & Document Search** in `pgvector`. | 30–50 simultaneous RAG queries / sec.<br/>Local 7B model latency: ~10–18 tokens/sec (CPU). |
| **Dedicated GPU VPS**<br/>*(1x NVIDIA RTX 4090 / L4 / T4: 16–24GB VRAM)* | **$150 – $350 / mo**<br/>*(~$0.30 – $0.55 / hr on RunPod, Lambda, Hetzner GPU, Vast.ai)*<br/><br/>*Enterprise Cloud (AWS g5/g6 / GCP g2): ~$450 – $650 / mo* | • `llama3.1:8b / 14b` (FP16 / AWQ)<br/>• `mistral-nemo:12b`<br/>• `deepseek-r1:14b`<br/>• `qwen2.5-coder:7b/14b` | • **High-Throughput Enterprise Inference** via **vLLM** with PagedAttention and continuous batching.<br/>• **Real-Time Streaming Chat & Coding Copilots**.<br/>• **Zero-Data-Egress Private Cloud** for healthcare, legal, and fintech startups. | **100+ concurrent streaming users** at **60–120 tokens/sec**.<br/>Zero external API token bills! |

---

## 3. Common Services AI Startups Need from `vps-infra`

Just as `vps-infra` provided PostgreSQL, MariaDB, SQL Server, Oracle, Redis, Traefik, and Backups for web/mobile apps, the platform provides a **"Batteries-Included AI Service Stack"**:

```mermaid
graph TD
    subgraph StartupCode ["Startup's Application (Business Logic Only)"]
        Agent["AI Agent / RAG Backend (Python / Node / .NET)"]
    end

    subgraph VPSInfraServices ["VPS-Infra Provided Platform Dependencies"]
        VDB["1. Vector Store: PostgreSQL + pgvector (Semantic Search Index)"]
        AIGW["2. AI Gateway: LiteLLM / Proxy (Semantic Cache + Token Router)"]
        LocalModel["3. Local Model Engine: Ollama / vLLM (1-Click Local Models)"]
        StateDB["4. State & Checkpoint Store: Redis / Postgres (Agent Memory)"]
        ToolBox["5. Sandboxed Tool Execution: Isolated Docker Runners"]
        TraceHub["6. Observability & Evals: Langfuse / OpenTelemetry Spans"]
        CronBkup["7. Automated Vector & State Snapshots (Quartz + Offsite Sync)"]
    end

    Agent --> VDB
    Agent --> AIGW
    AIGW --> LocalModel
    Agent --> StateDB
    Agent --> ToolBox
    Agent --> TraceHub
```

### The 6 Pre-Packaged AI Services:

1. **Vector Database (`pgvector` by default)**:
   - PostgreSQL enabled with `CREATE EXTENSION IF NOT EXISTS vector;`.
   - Startups get high-speed HNSW/IVFFlat indexing without paying $70+/month for third-party vector SaaS (Pinecone/Milvus).
2. **AI Proxy Gateway (LiteLLM Proxy / Custom Router)**:
   - Unified endpoint (`http://ai-gateway:4000/v1/chat/completions`) standardizing OpenAI, Anthropic, DeepSeek, Google Gemini, and Local Ollama.
   - Startups use standard OpenAI SDKs and switch models with 1 line of configuration.
3. **Local Embedding & Inference Engine (Ollama Container)**:
   - Pre-installed `ollama` container on internal `traefik_net`.
   - 1-click model pulls (`ollama pull nomic-embed-text`, `ollama pull llama3.2:3b`).
4. **Agent State & Memory Store (Redis + PostgreSQL)**:
   - Redis for low-latency session caching and message queues.
   - PostgreSQL for durable checkpointing (enabling agents to pause for human approvals and resume without data loss).
5. **Sandboxed Tool Runners (Isolated Docker Execution)**:
   - Secure container sandbox where agents execute Python code, scrape web pages, or query SQL without compromising the host server.
6. **AI Observability & Cost Tracking (Langfuse)**:
   - Open-source, self-hosted Langfuse dashboard tracking prompt tokens, completion tokens, latency, and costs per user/tenant.

---

## 4. Local Models vs. Premium Models & Cost Optimization

Startups face a dilemma: **Frontier cloud models (GPT-4o, Claude 3.5) are smart but expensive; Local models are free but require compute**.

`vps-infra` solves this using a **Hybrid AI Strategy**:

```mermaid
graph LR
    Query["Incoming User Request"] --> Gateway["AI Gateway (Semantic Cache)"]
    Gateway -->|"Cache Hit (Cosine >= 0.96)"| FastResp["Instant Response (< 20ms, $0 Cost)"]
    Gateway -->|"Cache Miss"| Router["Complexity Router"]
    Router -->|"Simple: Extraction / RAG / Summarize"| LocalModel["Local Model (Ollama: Llama-3.2 / DeepSeek 1.5B) ($0 Compute)"]
    Router -->|"Complex: Reasoning / Code Gen / Planning"| PremiumModel["Premium Cloud (GPT-4o / Claude 3.5 / DeepSeek-V3) (Pay-per-Token)"]
```

### 1. The 3-Tier Model Hierarchy
* **Tier 1: Semantic Cache (Redis / pgvector)**:
  - If a user prompt matches a historical query with $\ge 96\%$ cosine similarity, return the cached completion in $< 20\text{ms}$.
  - **Result**: Slashes API token spend by **25%–40%** at $0 additional compute.
* **Tier 2: Local Open-Weights Models (Ollama / vLLM)**:
  - Used for 80% of routine tasks: classification, document chunk embedding, entity extraction, data formatting, and simple RAG.
  - **Cost**: $0.00 in API tokens (runs on existing VPS RAM/CPU).
* **Tier 3: Premium Frontier Models (OpenAI, Anthropic, DeepSeek, Gemini)**:
  - Used only for high-stakes 20% tasks: complex multi-step planning, intricate code generation, and critical business decisions.

### 2. Built-in Multi-Tenant Billing & Token Quotas
The platform meters:
- Prompt tokens, completion tokens, and dollar spend per startup/app.
- **Token Leaky-Bucket Rate Limiting**: Prevents runaway billing if an agent enters an infinite retry loop.

---

## 5. Division of Responsibility: Startup vs. `vps-infra` Platform

| Startup Responsibility (Business Logic Only) | `vps-infra` Platform Responsibility (We Handle Everything Else) |
| :--- | :--- |
| 1. Writing the Agent's Prompts and instructions | **Pre-configured Traefik HTTPS** routing & custom domains |
| 2. Defining business tools (e.g., `BookFlightTool`, `QueryInventoryAPI`) | **Zero-Downtime Deployment** via Git push webhooks |
| 3. Building their UI / Mobile App | **Local Embeddings & Model Serving** via Ollama container |
| 4. Selecting which models to query | **Vector Storage & Indexing** via PostgreSQL `pgvector` |
| 5. Setting up business database tables | **Semantic Caching & Token Cost Optimization** to cut API bills |
| | **Durable State Checkpointing** for pause/resume and human approvals |
| | **Automated Multi-Engine DB & Volume Backups** to Google Drive/S3 |
| | **Deep Tracing & LLM Evals** via self-hosted Langfuse & DeepEval |

---

## 6. Implementation Blueprint: The "AI-Native Stack" Add-on

To enable this on any `vps-infra` deployment, add `docker-compose.ai.yml`:

```yaml
version: '3.8'

services:
  # 1. Local Model Serving Engine
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: always
    volumes:
      - /var/www/vps-infra/volumes/infra/ollama:/root/.ollama
    networks:
      - traefik_net
    environment:
      - OLLAMA_KEEP_ALIVE=24h

  # 2. Universal AI Proxy Gateway with Semantic Cache
  ai-gateway:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: ai-gateway
    restart: always
    environment:
      - DATABASE_URL=postgresql://postgres:StrongPostgres@123@shared_postgres:5432/devops_prod
      - REDIS_HOST=shared_redis
      - REDIS_PORT=6379
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.ai-gateway.rule=Host(`ai-api.${BASE_DOMAIN:-example.com}`)"
      - "traefik.http.routers.ai-gateway.entrypoints=websecure"
      - "traefik.http.routers.ai-gateway.tls=true"
      - "traefik.http.routers.ai-gateway.tls.certresolver=myresolver"
      - "traefik.http.services.ai-gateway.loadbalancer.server.port=4000"

  # 3. LLMOps & Observability Dashboard
  langfuse:
    image: ghcr.io/langfuse/langfuse:2
    container_name: langfuse
    restart: always
    environment:
      - DATABASE_URL=postgresql://postgres:StrongPostgres@123@shared_postgres:5432/devops_prod
    networks:
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.langfuse.rule=Host(`traces.${BASE_DOMAIN:-example.com}`)"
      - "traefik.http.routers.langfuse.entrypoints=websecure"
      - "traefik.http.routers.langfuse.tls=true"
      - "traefik.http.routers.langfuse.tls.certresolver=myresolver"
      - "traefik.http.services.langfuse.loadbalancer.server.port=3000"

networks:
  traefik_net:
    external: true
```

---

## 7. Summary & Pitch to Startups

> *"You build the agent's brain and business logic; our platform gives you the vector database, local AI models, universal gateway, semantic caching, automated backups, and SSL routing out-of-the-box on a single $20/month VPS."*
