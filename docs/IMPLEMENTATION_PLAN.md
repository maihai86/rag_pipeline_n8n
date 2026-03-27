# Implementation Plan: RAG + MCP + n8n Chatbot Backend

## Context

Building a chatbot backend system combining:
- **n8n** — orchestration layer (workflow automation, drag-and-drop UI)
- **Qdrant** — vector database (already adopted)
- **MCP servers** — extend chatbot capabilities (web search via Brave Search)
- **Docker** — containerization platform (already available)

**Approach**: 100% out-of-the-box solutions. No custom code — leverage n8n nodes, MCP servers, and LLM APIs directly.

**Current state** (as of 2026-03-24):
- ✅ ARCHITECTURE.md — 6 layers, 5 ADRs, clear scope (backend only)
- ✅ `.mcp.json` — GitHub MCP configured for Claude Code (dev tool), token via `${GITHUB_TOKEN}`
- ⬜ No `docker-compose.yml` yet
- ⬜ No n8n workflows yet

---

## Open-Source Solutions Stack

| Component | Solution | Source |
|-----------|----------|--------|
| **n8n Docker setup** | `n8n-io/self-hosted-ai-starter-kit` | Official n8n repo with docker-compose (n8n + Qdrant + sample workflows) |
| **n8n hosting reference** | `n8n-io/n8n-hosting` | Postgres + Redis queue mode examples |
| **MCP Servers** | `modelcontextprotocol/servers` | Anthropic official — brave-search, fetch, memory |
| **Qdrant** | `qdrant/qdrant` | Official Docker image (`qdrant/qdrant:latest`) |
| **RAG Workflow refs** | `n8n.io/workflows` + `coleam00/ottomator-agents` | Community n8n workflow templates |

---

## Chatbot Scope

The chatbot has two tool capabilities:
1. **RAG retrieval** — search internal knowledge base via Qdrant vector DB
2. **Web search** — real-time internet search via Brave Search (MCP or n8n HTTP Request)

> **Note**: `.mcp.json` (GitHub MCP) is a **dev tool** for Claude Code only. It is NOT part of the chatbot backend.

---

## Implementation Phases

### Phase 1: Bootstrap Infrastructure (Days 1–2)

Core infrastructure only. MCP servers (web search) added in Phase 2 alongside workflows.

**Task 1.1**: Create `docker-compose.yml`
- **Reference**: `n8n-io/self-hosted-ai-starter-kit` — adapt for cloud LLMs
- **Services**:

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `n8n` | `n8nio/n8n:latest` | 5678 | Orchestrator + API endpoints |
| `postgres` | `postgres:16` | 5432 | n8n backend DB |
| `qdrant` | `qdrant/qdrant:latest` | 6333 | Vector database |

- **Key decisions**:
  - Remove `ollama` from starter-kit (using cloud LLMs: Claude/GPT)
  - Qdrant with persistent Docker volume (avoid data loss on restart)
  - Postgres for n8n state (workflows, credentials, execution history)
- **Verification**: `docker-compose up -d` → all services healthy

**Task 1.2**: Create `.env.example` + `.env`
```
# LLM APIs
OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key

# Web Search (Brave Search API)
BRAVE_API_KEY=your_brave_api_key

# n8n
N8N_ENCRYPTION_KEY=your_random_encryption_key

# Postgres
POSTGRES_USER=n8n
POSTGRES_PASSWORD=your_postgres_password
POSTGRES_DB=n8n
```

**Task 1.3**: Create `.gitignore`
```
.env
*.log
n8n_data/
qdrant_data/
postgres_data/
```

**Verification**: `docker-compose up -d` → access n8n at `http://localhost:5678`

---

### Phase 2: n8n Workflows (Days 3–7)

> **Note**: n8n workflows are built in the **n8n web UI** (drag-and-drop), then exported as JSON for version control. This phase documents the workflow designs to build manually in n8n.

#### Workflow 2.1: Ingestion Pipeline (build first — need data before retrieval)

**Name**: `Ingest Documents`
**Trigger**: Manual or Schedule

```
┌──────────┐   ┌────────────┐   ┌─────────────────────┐   ┌──────────┐
│ Trigger  │──▶│ Read Files │──▶│ Default Data Loader │──▶│ Recursive│
│ (Manual) │   │ (folder)   │   │ (text extraction)    │   │ Text     │
└──────────┘   └────────────┘   └─────────────────────┘   │ Splitter │
                                                           └────┬─────┘
                                                                │
                                                                ▼
                                                    ┌─────────────────┐
                                                    │ Embeddings       │
                                                    │ (OpenAI)         │
                                                    └────────┬────────┘
                                                             │
                                                             ▼
                                                    ┌─────────────────┐
                                                    │ Qdrant Vector   │
                                                    │ Store (Insert)  │
                                                    └─────────────────┘
```

**n8n nodes used** (all built-in):
- `Read/Write Files from Disk` — read documents from mounted volume
- `Default Data Loader` — n8n's built-in document loader
- `Recursive Character Text Splitter` — chunking (chunk size: 1000, overlap: 200)
- `Embeddings OpenAI` — `text-embedding-3-small`
- `Qdrant Vector Store` — insert mode, connect to `qdrant:6333`

---

#### Workflow 2.2: Chat Main (core chatbot workflow)

**Name**: `Chat Main`
**Trigger**: Webhook (POST `/chat`) or n8n Chat Trigger (for dev testing)

```
┌────────────┐   ┌──────────────┐   ┌────────────────┐
│ Chat       │──▶│  AI Agent    │──▶│ Response       │
│ Trigger /  │   │  (Tools      │   │ (to user)      │
│ Webhook    │   │   Agent)     │   └────────────────┘
└────────────┘   └──────┬───────┘
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
   ┌────────────┐┌───────────┐┌────────────┐
   │ Qdrant     ││ Web       ││ Window     │
   │ Vector     ││ Search    ││ Buffer     │
   │ Store      ││ (Brave)   ││ Memory     │
   │ (Retrieve) ││           ││ (Postgres) │
   └────────────┘└───────────┘└────────────┘
```

**n8n nodes used**:
- `Chat Trigger` — built-in chat interface (dev) / `Webhook` (production)
- `AI Agent` — Tools Agent type, connected to Claude Sonnet via Anthropic API
- `Qdrant Vector Store` — retriever mode (top-k = 5)
- `Embeddings OpenAI` — same model as ingestion
- `HTTP Request` or `MCP Client` — Brave Search API for web search
- `Window Buffer Memory` — conversation history in Postgres

**AI Agent system prompt** (simplified):
```
You are a helpful assistant with access to a knowledge base and web search.
- Use the vector store tool to search internal documents when the user asks about specific topics.
- Use the web search tool when the user asks about recent events, real-time information, or topics not in the knowledge base.
- If you don't know the answer and no tool helps, say "I don't know."
- Always cite your sources.
```

---

#### Workflow 2.3: Error Handler

**Name**: `Error Handler`
**Trigger**: Error workflow (configured in n8n settings)

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Error        │──▶│ Set Error    │──▶│ Respond to   │
│ Trigger      │   │ Details      │   │ Webhook      │
└──────────────┘   └──────────────┘   └──────────────┘
```

Returns: `{ "error": true, "message": "Something went wrong. Please try again." }`

---

#### Workflow 2.4: Health Check

**Name**: `Health Check`
**Trigger**: Webhook GET `/health`

```
┌──────────┐   ┌─────────────┐   ┌────────────┐   ┌──────────┐
│ Webhook  │──▶│ HTTP Request│──▶│ Merge      │──▶│ Respond  │
│ GET      │   │ (Qdrant     │   │ Results    │   │ to       │
└──────────┘   │  health)    │   └────────────┘   │ Webhook  │
               └─────────────┘                     └──────────┘
```

---

### Phase 3: Test & Validate (Days 8–9)

**Task 3.1**: Ingest sample documents
- Prepare 5–10 sample documents (PDF, MD) in a mounted volume
- Run Ingestion Pipeline workflow
- Verify chunks in Qdrant via REST API: `GET http://localhost:6333/collections`

**Task 3.2**: Test Chat Main end-to-end
- Use n8n Chat Trigger (built-in chat UI) for quick testing
- Test cases:

| Test Case | Expected Behavior |
|-----------|-------------------|
| Knowledge question | AI Agent retrieves from Qdrant, cites source |
| Web search question | AI Agent calls web search → returns real-time results |
| General chat | Direct LLM response (no tool call) |
| Unknown topic | "I don't know" response |
| Error scenario | Error Handler returns graceful fallback |

**Task 3.3**: Test API contract via curl
```bash
# Chat endpoint
curl -X POST http://localhost:5678/webhook/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is RAG?"}'

# Health endpoint
curl http://localhost:5678/webhook/health
```

---

### Phase 4: Expand Capabilities (Days 10+, incremental)

Add more tools as needed. Each is a new service in `docker-compose.yml` + a new tool node in the Chat Main workflow.

| Tool | Source | Priority | Notes |
|------|--------|----------|-------|
| **Filesystem MCP** | `modelcontextprotocol/servers` → filesystem | Medium | Read internal docs |
| **Postgres MCP** | `modelcontextprotocol/servers` → postgres | Low | Query structured data |

---

## File Inventory

| File | Action | Phase |
|------|--------|-------|
| `docker-compose.yml` | Create | Phase 1 |
| `.env` / `.env.example` | Create | Phase 1 |
| `.gitignore` | Create | Phase 1 |
| `workflows/ingestion_pipeline.json` | Export from n8n | Phase 2 |
| `workflows/chat_main.json` | Export from n8n | Phase 2 |
| `workflows/error_handler.json` | Export from n8n | Phase 2 |
| `workflows/health_check.json` | Export from n8n | Phase 2 |
| `sample_docs/` | Create sample data | Phase 3 |
| `ARCHITECTURE.md` | Already done | — |
| `CLAUDE.md` | Already done | — |

---

## Known Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| **Qdrant data loss on restart** | Docker volume mount (`qdrant_data:/qdrant/storage`) |
| **No streaming in n8n** | Accept for v1; Chat UI can poll. Consider SSE proxy later |
| **MCP Client node availability** | Verify n8n version has MCP Client node; fallback: HTTP Request node |
| **Token overflow in RAG context** | Limit top-k to 3–5; use reranking in future iteration |
| **n8n cold-start** | Accept ~5s first request; queue mode (Redis) for production |

---

## Success Criteria

- [ ] `docker-compose up -d` starts all services cleanly
- [ ] n8n accessible at `http://localhost:5678`
- [ ] Qdrant accessible at `http://localhost:6333`
- [ ] Ingestion workflow ingests sample docs into Qdrant
- [ ] Chat Main workflow responds to messages via n8n Chat Trigger
- [ ] AI Agent uses Qdrant retrieval for knowledge questions
- [ ] AI Agent uses web search for real-time information questions
- [ ] `/webhook/health` returns service status
- [ ] Error handler returns graceful message on failure
- [ ] All workflows exported as JSON in `workflows/` directory
- [ ] `.env` is gitignored; `.env.example` documents all variables
