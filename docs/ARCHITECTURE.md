# RAG + MCP + n8n Chatbot — System Architecture

> **Scope**: This repository covers the **backend system only**.
> Chat UI is maintained in a separate repository.

## Existing Infrastructure

- **Docker**: Available — all services will be containerized
- **Qdrant Vector DB**: Already adopted — used as the primary vector store for RAG retrieval

## Architecture Decisions

| ID    | Decision                                      | Rationale                                                    |
| ----- | --------------------------------------------- | ------------------------------------------------------------ |
| ADR-1 | Chat UI in separate repository                | Decoupled frontend/backend; independent deploy cycles        |
| ADR-2 | Backend exposes REST API for Chat UI (via n8n Webhook node — n8n's mechanism for creating HTTP endpoints, not a traditional webhook callback) | Clean contract; any UI framework can integrate |
| ADR-3 | MCP servers run as always-on Docker containers| Avoids cold-start latency (~1-2s); simpler than dynamic spawn |
| ADR-4 | No docker.sock mount                          | Security: socket mount = root-level host access. Not worth the risk for this use case |
| ADR-5 | Docker interaction via docker-compose only    | All container lifecycle managed declaratively, not at runtime |

---

## High-Level Architecture

```
 ┌──────────────────────────┐
 │  CHAT UI                 │  ◄── Separate Repository
 │  (Web App)               │
 └────────────┬─────────────┘
              │ REST API (HTTP POST)
              │
╔═════════════▼═══════════════════════════════════════════════════╗
║  BACKEND SYSTEM (this repo)                                     ║
║                                                                  ║
┌────────────────────────────────────────────────────────────────────┐
│  ORCHESTRATION LAYER (n8n)                                       │
│                                                                  │
│  ┌──────────┐    ┌──────────────┐    ┌────────────────────┐     │
│  │ Webhook  │───▶│  AI Agent    │───▶│  Response           │     │
│  │ Trigger  │    │  (Router)    │    │  Formatter          │     │
│  └──────────┘    └──────┬───────┘    └────────────────────┘     │
│                         │                                        │
│            ┌────────────┼────────────┐                           │
│            ▼            ▼            ▼                           │
│     ┌────────────┐┌──────────┐┌───────────┐                    │
│     │ RAG Sub-   ││ MCP Tool ││ Direct    │                    │
│     │ Workflow   ││ Router   ││ LLM Call  │                    │
│     └─────┬──────┘└────┬─────┘└─────┬─────┘                    │
│           │            │            │                            │
└───────────┼────────────┼────────────┼────────────────────────────┘
            │            │            │
┌───────────▼────┐┌──────▼──────┐┌────▼──────┐
│ RETRIEVAL      ││ TOOL LAYER  ││ GENERATION│
│ LAYER          ││ (MCP)       ││ LAYER     │
│                ││             ││           │
│ Query Transform││ ┌─────────┐ ││ LLM API  │
│       │        ││ │ Web     │ ││ (Claude/ │
│       ▼        ││ │ Search  │ ││  GPT)    │
│ Embedding      ││ ├─────────┤ ││           │
│       │        ││ │ Custom  │ ││           │
│       ▼        ││ │ Tools   │ ││           │
│ Vector Search  ││ └─────────┘ ││           │
│  (Qdrant)      ││             ││           │
│       │        ││             ││           │
│       ▼        ││             ││           │
│ Reranking      ││             ││           │
│       │        ││             ││           │
│       ▼        ││             ││           │
│ Context Builder││             ││           │
└────────────────┘└─────────────┘└───────────┘
            │            │            │
            └────────────┼────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│  INGESTION LAYER (Offline / Batch)                               │
│                                                                  │
│  ┌──────────┐   ┌───────────┐   ┌──────────┐   ┌────────────┐ │
│  │ Document │──▶│ Parser /  │──▶│ Chunking │──▶│ Embedding  │ │
│  │ Sources  │   │ Extractor │   │ Engine   │   │ + Indexing │ │
│  └──────────┘   └───────────┘   └──────────┘   └─────┬──────┘ │
│   PDF, MD,       Unstructured    Recursive             │        │
│   HTML, API      / LlamaParse    512-1024 tok          │        │
│                                                        ▼        │
│                                                  ┌──────────┐  │
│                                                  │  Qdrant   │  │
│                                                  └──────────┘  │
└─────────────────────────────────────────────────────────────────┘
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Layer Details

### Layer 1 — Ingestion (Offline / Batch)

Chạy độc lập, không nằm trong luồng chat real-time.

| Stage           | Component                          | Notes                                    |
| --------------- | ---------------------------------- | ---------------------------------------- |
| **Source**      | Files (PDF, MD, HTML), APIs, Web   | n8n workflow trigger: schedule hoặc manual |
| **Parsing**     | Unstructured / LlamaParse          | Extract text + metadata từ diverse formats |
| **Chunking**    | Recursive Text Splitter            | 512–1024 tokens, overlap 50–100 tokens   |
| **Embedding**   | OpenAI `text-embedding-3-small` hoặc local model | Batch processing, lưu vào Qdrant        |
| **Storage**     | Qdrant (Docker)                    | Collections phân theo domain/source      |

**Data flow**: `Source → Parse → Chunk → Embed → Qdrant`

---

### Layer 2 — Retrieval (RAG Pipeline)

Được gọi bởi n8n sub-workflow khi AI Agent cần knowledge context.

```
User Query
    │
    ▼
┌─────────────────┐
│ Query Transform  │  ← Rewrite / expand / decompose query
└────────┬────────┘
         ▼
┌─────────────────┐
│ Embedding        │  ← Embed query với cùng model đã dùng cho ingestion
└────────┬────────┘
         ▼
┌─────────────────┐
│ Vector Search    │  ← Qdrant: top-k (k=10–20), có thể kết hợp metadata filter
└────────┬────────┘
         ▼
┌─────────────────┐
│ Reranking        │  ← Cross-encoder hoặc Cohere Rerank → top-k (k=3–5)
└────────┬────────┘
         ▼
┌─────────────────┐
│ Context Builder  │  ← Format retrieved chunks thành prompt context
└─────────────────┘
```

---

### Layer 3 — Tool Layer (MCP Servers)

MCP servers chạy như Docker containers, giao tiếp qua **stdio**.

| MCP Server        | Purpose                          | Status      |
| ----------------- | -------------------------------- | ----------- |
| **Web Search**    | Real-time web context (Brave Search) | 📋 Phase 2  |
| **Custom**        | Domain-specific business logic   | 📋 Future   |

**Integration pattern**: n8n AI Agent → MCP Tool Node → MCP Server (Docker) → Response

---

### Layer 4 — Orchestration (n8n)

Trung tâm điều phối toàn bộ hệ thống.

#### Core Workflows

| Workflow               | Trigger              | Purpose                              |
| ---------------------- | -------------------- | ------------------------------------ |
| **Chat Main**          | Webhook (POST)       | Entry point, route tới AI Agent      |
| **RAG Retrieval**      | Sub-workflow call    | Query → Qdrant → Rerank → Context   |
| **Ingestion Pipeline** | Schedule / Manual    | Ingest documents vào Qdrant          |
| **Error Handler**      | Error trigger        | Log errors, notify, fallback response |

#### AI Agent Decision Flow

```
User Message
    │
    ▼
┌──────────────┐
│  AI Agent    │
│  (LangChain) │
└──────┬───────┘
       │ Decides action based on intent
       │
       ├──▶ Needs knowledge?     → Call RAG Sub-Workflow
       ├──▶ Needs external tool? → Call MCP Tool (Web Search, ...)
       ├──▶ Simple conversation? → Direct LLM response
       └──▶ Complex task?        → Chain multiple tools + RAG
```

---

### Layer 5 — Generation (LLM)

| Provider     | Model                 | Use Case                         |
| ------------ | --------------------- | -------------------------------- |
| **Anthropic**| Claude Sonnet/Opus    | Primary: reasoning, generation   |
| **OpenAI**   | GPT-4o                | Alternative / fallback           |
| **Local**    | Llama / Mistral       | Cost optimization (future)       |

---

### Layer 6 — API Interface

Backend exposes REST API endpoints thông qua **n8n Webhook node** (cơ chế tạo HTTP endpoint của n8n, hoạt động như REST API request-response bình thường, không phải webhook callback truyền thống). Chat UI (separate repo) gọi vào các endpoints này.

| Endpoint           | Method | Purpose                          |
| ------------------ | ------ | -------------------------------- |
| `/chat`            | POST   | Send message, receive response   |
| `/chat/history`    | GET    | Retrieve conversation history    |
| `/health`          | GET    | Backend health check             |

> **Note**: n8n Chat Widget vẫn có thể dùng để test nhanh trong quá trình development, nhưng production UI nằm ở repo riêng.

---

## Docker Composition (Target)

All services managed declaratively via `docker-compose.yml`. No runtime Docker manipulation (ADR-4, ADR-5).

```
docker-compose.yml
│
├── n8n              (port 5678)   — Orchestrator + API Gateway
├── postgres         (port 5432)   — n8n backend DB + conversation memory
├── qdrant           (port 6333)   — Vector DB
├── [web-search-mcp] (always-on)   — Web Search MCP (Phase 2)
└── [redis]          (port 6379)   — n8n queue mode (optional, for scaling)
```

**No `docker.sock` mount** — container lifecycle is fully managed by docker-compose, not by the application at runtime. This avoids granting root-level host access to any container.

---

## Data Flow Summary

```
                    OFFLINE                              REAL-TIME
              ┌─────────────────┐              ┌──────────────────────────┐
              │                 │              │                          │
  Documents ──▶ Ingest Pipeline ──▶ Qdrant ◀── RAG Retrieval ◀── AI Agent
              │   (n8n workflow)│              │                    │     │
              └─────────────────┘              │              ┌────┘     │
                                               │              ▼          ▼
                                               │         MCP Tools    LLM API
                                               │              │          │
                                               │              └────┬─────┘
                                               │                   ▼
                                               │            JSON Response
                                               │                   │
                                               │                   ▼ REST API
                                               │            Chat UI (separate repo)
                                               └──────────────────────────┘
```

---

## Next Steps

1. [ ] Set up `docker-compose.yml` với n8n + Postgres + Qdrant
2. [ ] Build Ingestion workflow trong n8n
3. [ ] Build RAG Retrieval sub-workflow
4. [ ] Build Chat Main workflow với AI Agent node (Qdrant + Web Search)
5. [ ] Integrate thêm MCP servers nếu cần
6. [ ] Evaluation pipeline (RAGAS / DeepEval)
