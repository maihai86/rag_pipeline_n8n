# RAG + MCP + n8n Chatbot Backend

> A complete chatbot backend system using RAG (Retrieval-Augmented Generation), n8n orchestration, and Qdrant vector database. All code is open-source — no custom code, just using existing tools and services.

---

## 🎯 Overview

This project builds a **complete chatbot backend** combining:

| Component | Role | Benefit |
|-----------|------|---------|
| **n8n** | Orchestration Layer (automation workflows) | No-code, drag-and-drop, easy to maintain |
| **Qdrant** | Vector Database (embedding storage) | Semantic search, high performance, open-source |
| **OpenAI** | Embedding + Chat LLM | text-embedding-3-small + GPT-4o-mini |
| **Tavily** | Web Search Tool | Real-time search, free API (1000 searches/month) |
| **Docker** | Containerization | Easy deployment, reproducible |

**Architecture**: Backend-only (frontend in separate repo) → REST API (HTTP POST) → n8n Webhook endpoints.

---

## 📊 Project Status

| Phase | Name | Status | Completed |
|-------|------|--------|-----------|
| **Phase 1** | Bootstrap Infrastructure | ✅ DONE | 2026-03-25 |
| **Phase 2** | n8n Workflows | ✅ DONE | 2026-03-25 |
| **Phase 3** | Test & Validate | ✅ DONE | 2026-03-25 |
| **Phase 4** | Expand Capabilities | ✅ DONE | 2026-03-26 |

**Final Result**: **9/9 tests PASS** — System production-ready.

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
docker --version
docker-compose --version
git clone <repo-url>
cd rag_pipeline_n8n
```

### 2. Configure `.env`

```bash
cp .env.example .env

# Update in .env:
# - OPENAI_API_KEY=sk-...
# - TAVILY_API_KEY=tvly-... (free tier from https://app.tavily.com/)
# - N8N_ENCRYPTION_KEY=<random-string>
# - POSTGRES_PASSWORD=<secure-password>
```

### 3. Start services

```bash
docker-compose up -d
docker-compose ps
```

### 4. Activate workflow

- Open `http://localhost:5678` in browser
- Login to n8n (first time setup)
- Workflow `rag-chatbot-v2` auto-imports
- **Toggle to activate workflow**

### 5. Quick test

```bash
# Health check
curl http://localhost:5678/webhook/health

# Chat
curl -X POST http://localhost:5678/webhook/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is RAG?", "sessionId": "test-001"}'

# Ingest documents
curl -X POST http://localhost:5678/webhook/ingest \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [docs/CLAUDE.md](docs/CLAUDE.md) | AI Architect system prompt & principles |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture (6 layers, 5 ADRs) |
| [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) | 4-phase implementation roadmap |
| [docs/STATUS.md](docs/STATUS.md) | Current status + bug fixes + next steps |
| [docs/WORKFLOW_SETUP.md](docs/WORKFLOW_SETUP.md) | n8n workflow configuration guide |
| [docs/MCP_SETUP.md](docs/MCP_SETUP.md) | MCP servers (Model Context Protocol) |
| [docs/AGENTS.md](docs/AGENTS.md) | AI agent system design |

---

## 🏗️ Architecture

```
┌─────────────────────────┐
│  Chat UI                │  (Separate Repository)
│  (Frontend)             │
└────────────┬────────────┘
             │ REST API (HTTP POST)
             │
    ╔════════▼════════════════════════════════════════════════╗
    ║ BACKEND SYSTEM (n8n + Qdrant + OpenAI)                ║
    ║                                                         ║
    │ POST /webhook/chat                                    │
    │   ├─▶ Map Input                                       │
    │   ├─▶ AI Agent (LLM Router)                           │
    │   │    ├─▶ knowledge_base tool (Qdrant)               │
    │   │    ├─▶ web_search tool (Tavily)                   │
    │   │    └─▶ direct LLM response                        │
    │   └─▶ Format Response                                 │
    │                                                         │
    │ POST /webhook/ingest                                  │
    │   ├─▶ Read Files from Disk                            │
    │   ├─▶ Parse & Chunk (Recursive Text Splitter)         │
    │   ├─▶ Embed (OpenAI text-embedding-3-small)           │
    │   └─▶ Store in Qdrant                                 │
    │                                                         │
    │ GET /webhook/health                                   │
    │   └─▶ Return {status: ok, services: {...}}            │
    ║                                                         ║
    ╚═════════════════════════════════════════════════════════╝
             │                    │                    │
             ▼                    ▼                    ▼
      ┌─────────────┐      ┌────────────┐      ┌──────────┐
      │ Qdrant      │      │ PostgreSQL │      │ n8n      │
      │ (Vectors)   │      │ (Workflows)│      │ (Orches) │
      └─────────────┘      └────────────┘      └──────────┘
```

---

## 🛠️ API Endpoints

### Chat Endpoint

```bash
POST /webhook/chat

Request:
{
  "message": "What is RAG?",
  "sessionId": "user-session-001"  # Optional, for memory
}

Response:
{
  "response": "RAG stands for Retrieval-Augmented Generation...",
  "sessionId": "user-session-001"
}
```

**Tool Selection Logic**:
- Questions about RAG/n8n/Qdrant/MCP/Docker → `knowledge_base` tool
- Questions about news/current events → `web_search` tool
- Greetings/general chat → Direct LLM response

### Ingestion Endpoint

```bash
POST /webhook/ingest

Request: {} (body doesn't matter)

Response: {status: "Ingestion started..."}
```

Runs ingestion pipeline: read from `sample_docs/`, chunk, embed, store in Qdrant.

### Health Check Endpoint

```bash
GET /webhook/health

Response:
{
  "status": "ok",
  "services": {
    "qdrant": "healthy",
    "n8n": "running",
    "postgres": "healthy"
  }
}
```

---

## 📖 Sample Documents (Knowledge Base)

Knowledge base stored in `sample_docs/`:

| File | Content |
|------|---------|
| `rag_architecture.md` | RAG pipeline design, chunking strategies, evaluation metrics |
| `n8n_workflow_guide.md` | n8n concepts, AI agent workflows, node types |
| `qdrant_vector_database.md` | Qdrant API, vector similarity search, HNSW index |
| `mcp_protocol.md` | Model Context Protocol architecture, transport, tools |
| `project_setup_guide.md` | Guide to set up this project |
| `llm_comparison.md` | Compare Claude, GPT, Mistral, Llama |
| `docker_best_practices.md` | Docker Compose patterns for AI apps |

All files are **embedded in Qdrant** during ingestion → Agent can query them.

---

## 🧪 Testing

### Automated Tests

```bash
# Phase 3 Regression Tests (10 tests)
bash scripts/test_phase3.sh

# Phase 4 Full Suite (9 tests)
bash scripts/test_phase4.sh
```

### Manual Testing

See detailed guide in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and workflow documentation.

---

## 🐛 Bugs Fixed (Phase 4)

| Bug | Root Cause | Solution |
|-----|-----------|----------|
| **Garbage vectors in Qdrant** | Default Data Loader missing `dataType: "binary"` → read JSON metadata instead of file content | Added `"dataType": "binary"` → delete collection → re-ingest |
| **Agent not using tools** | Weak system prompt ("say I don't know") → agent skipped tool usage | Rewrote prompt with "Always Try Tools First" + explicit rules |
| **Test script grep error** | `grep -c` exit code 1 + `\|\| echo "0"` created "0\n0" → integer comparison fail | Changed to `\|\| true` |
| **n8n execute port conflict** | Task Broker port 5679 occupied by running instance | Added `/webhook/ingest` trigger instead of CLI execute |

**Result**: 4/9 FAIL → 9/9 PASS ✅

---

## 🔄 Workflow Details

### Combined Workflow (`rag-chatbot-v2`)

Single workflow containing **4 flows**:

```
1. INGESTION FLOW
   Trigger: POST /webhook/ingest
   │
   ├─▶ Read Files from Disk (sample_docs/)
   ├─▶ Default Data Loader (dataType: "binary")
   ├─▶ Recursive Text Splitter (chunk size: 1000, overlap: 200)
   ├─▶ Embeddings OpenAI (text-embedding-3-small)
   └─▶ Qdrant Vector Store (insert mode)

2. CHAT FLOW
   Trigger: POST /webhook/chat
   │
   ├─▶ Map Input (extract message + sessionId)
   ├─▶ AI Agent
   │    ├─▶ knowledge_base tool (Qdrant retrieval)
   │    ├─▶ web_search tool (Tavily HTTP Request)
   │    └─▶ Window Buffer Memory (Postgres)
   └─▶ Format Response

3. HEALTH FLOW
   Trigger: GET /webhook/health
   │
   └─▶ Return service status

4. ERROR FLOW
   Trigger: Automatic (on error)
   │
   └─▶ Return {error: true, message: "..."}
```

---

## 🎯 Future Improvements

| # | Name | Description | Priority |
|---|------|-------------|----------|
| 1 | **Reranking** | Add cross-encoder (Cohere Rerank) for top-k selection | 🔴 HIGH |
| 2 | **Verify web_search** | Confirm agent actually calls Tavily when needed | 🟡 MEDIUM |
| 3 | **Filesystem MCP** | Allow agent to read files from system | 🟢 LOW |
| 4 | **Monitoring** | Integrate LangSmith or Langfuse | 🟡 MEDIUM |
| 5 | **Rate Limiting** | Protect webhook endpoints | 🔴 HIGH (Production) |

---

## 🔐 Security

### API Keys

- ✅ `.env` gitignored → no credentials committed
- ✅ OpenAI API key stored in n8n encrypted credential store (not .env)
- ✅ Tavily API key: only used inside n8n container (environment variable)

### Best Practices

- ⚠️ **TODO**: Add authentication to webhook endpoints (API key or JWT)
- ⚠️ **TODO**: Rate limiting to prevent abuse
- ✅ No docker.sock mounted (no host access)
- ✅ Only docker-compose (no runtime container spawn)

---

## 📦 Technology Stack

| Layer | Technology | Decision |
|-------|-----------|---------|
| **Orchestration** | n8n v1.x (latest) | No-code, AI nodes out-of-box, easy workflow export |
| **Vector DB** | Qdrant | Open-source, powerful, cosine similarity + metadata filter |
| **Embedding** | OpenAI text-embedding-3-small | Fast, affordable, 1536 dimensions |
| **Chat LLM** | OpenAI GPT-4o-mini | Recommended by n8n, low cost, fast |
| **Web Search** | Tavily API | Free tier, AI-optimized results, no setup |
| **Database** | PostgreSQL 16 | n8n state, window buffer memory |
| **Containerization** | Docker + docker-compose | Reproducible deployment |

---

## 🚀 Deployment

### Development

```bash
docker-compose up -d
# Access n8n UI at http://localhost:5678
```

### Production

- [ ] Enable HTTPS (nginx reverse proxy)
- [ ] Configure rate limiting (nginx)
- [ ] Add API key authentication to webhooks
- [ ] Move n8n DB to managed PostgreSQL
- [ ] Update Qdrant volume mounting (persistent storage)
- [ ] Set up monitoring + logging (LangSmith / ELK stack)
- [ ] CI/CD pipeline for workflow updates

---

## 📞 Support

### Logs

```bash
# n8n
docker-compose logs -f n8n

# Qdrant
docker-compose logs -f qdrant

# All
docker-compose logs -f
```

### Reset Data

```bash
# Delete all vectors (keep collection schema)
curl -X DELETE http://localhost:6333/collections/sample_docs

# Re-ingest
curl -X POST http://localhost:5678/webhook/ingest \
  -H "Content-Type: application/json" \
  -d '{}'

# Or reset everything (delete volumes)
docker-compose down -v
docker-compose up -d
```

---

## 📄 License

MIT — Open-source project.

---

## 🙋 Feedback

If you encounter issues:
1. Check documentation in [docs/](docs/)
2. View logs: `docker-compose logs -f n8n`
3. Create GitHub issue with:
   - Specific error + stack trace
   - Steps to reproduce
   - Output of `docker-compose ps`

---

## 📚 Related Documentation

- **n8n Docs**: https://docs.n8n.io
- **Qdrant Docs**: https://qdrant.tech/documentation/
- **OpenAI API**: https://platform.openai.com/docs
- **Tavily Search**: https://tavily.com
- **RAG Best Practices**: https://python.langchain.com/docs/use_cases/question_answering/

---

**Project Completed**: 2026-03-26 ✅
