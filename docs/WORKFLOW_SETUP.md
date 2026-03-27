# n8n Workflow Setup Guide

## Prerequisites

- n8n running at http://localhost:5678
- All services healthy: `docker compose ps`
- Credentials configured in n8n Settings (see below)

---

## Step 1: Configure Credentials in n8n

Open n8n → **Settings → Credentials** and create 3 credentials:

### 1.1 OpenAI API

**Type**: OpenAI API
**Name**: `OpenAI`
**Config**:
- **API Key**: Copy from your `.env` file (`OPENAI_API_KEY`)

### 1.2 Anthropic API

**Type**: Anthropic API
**Name**: `Anthropic`
**Config**:
- **API Key**: Copy from your `.env` file (`ANTHROPIC_API_KEY`)

### 1.3 Qdrant API

**Type**: Qdrant
**Name**: `Qdrant`
**Config**:
- **Host**: `qdrant`
- **Port**: `6333`
- **API Key**: Leave empty (no auth required for local setup)

---

## Step 2: Import Workflows

### 2.1 Import Error Handler Workflow

**File**: `workflows/error_handler.json`

**Steps**:
1. Open n8n → **Workflows**
2. Click **Import from File**
3. Select `workflows/error_handler.json`
4. Click **Import**

**Configuration**:
- No credentials needed
- **Enable in Settings**:
  - Go to n8n **Settings → Error Workflow**
  - Select `Error Handler` from dropdown
  - Save

---

### 2.2 Import Health Check Workflow

**File**: `workflows/health_check.json`

**Steps**:
1. Open n8n → **Workflows**
2. Click **Import from File**
3. Select `workflows/health_check.json`
4. Click **Import**

**Configuration**:
- No credentials needed
- **Activate the workflow**:
  - In the workflow editor, toggle **Active** (top-right) to enable webhook
  - Webhook path: `/health` (automatically created)

**Verification**:
```bash
curl http://localhost:5678/webhook/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2026-03-25T...",
  "services": {
    "n8n": "healthy",
    "qdrant": "healthy",
    "qdrant_collections": 0
  }
}
```

---

### 2.3 Import Ingestion Pipeline Workflow

**File**: `workflows/ingestion_pipeline.json`

**Steps**:
1. Open n8n → **Workflows**
2. Click **Import from File**
3. Select `workflows/ingestion_pipeline.json`
4. Click **Import**

**Configuration**:

1. **Assign OpenAI credential**:
   - Open workflow editor
   - Click node `Embeddings OpenAI`
   - In right panel, select credential **OpenAI** (from Step 1.1)
   - Save

2. **Assign Qdrant credential**:
   - Click node `Qdrant Vector Store`
   - In right panel, select credential **Qdrant** (from Step 1.3)
   - Verify collection name is `sample_docs`
   - Save

3. **Prepare sample documents**:
   - Place 5–10 documents (PDF, MD, TXT) in `sample_docs/` directory
   - Example: `sample_docs/rag_guide.md`, `sample_docs/n8n_tutorial.pdf`

**Test run**:
1. Click **Test Workflow** (or **Execute Workflow**)
2. Check execution logs for errors
3. Expected output: "Successfully ingested N documents"

**Verify in Qdrant**:
```bash
curl http://localhost:6333/collections
```

You should see collection `sample_docs` with embedded documents.

---

### 2.4 Import Chat Main Workflow

**File**: `workflows/chat_main.json`

**Steps**:
1. Open n8n → **Workflows**
2. Click **Import from File**
3. Select `workflows/chat_main.json`
4. Click **Import**

**Configuration**:

1. **Assign Anthropic credential**:
   - Click node `Anthropic Chat Model`
   - In right panel, select credential **Anthropic** (from Step 1.2)
   - Verify model: `claude-sonnet-4-20250514`
   - Save

2. **Assign OpenAI credential**:
   - Click node `Embeddings OpenAI`
   - In right panel, select credential **OpenAI** (from Step 1.1)
   - Save

3. **Assign Qdrant credential**:
   - Click node `Qdrant Vector Store`
   - In right panel, select credential **Qdrant** (from Step 1.3)
   - Verify collection name is `sample_docs`
   - Verify retrieval mode is `retrieve` (not insert)
   - Save

4. **Add Web Search Tool** (manual step):
   - You need to add Brave Search as a tool to the AI Agent
   - In n8n, click on the `AI Agent` node
   - Under "Tools", click **Add Tool**
   - Select **HTTP Request** tool type
   - Configure:
     - **Method**: POST
     - **URL**: `https://api.search.brave.com/res/v1/web/search`
     - **Headers**: `Accept: application/json`, `X-Subscription-Token: YOUR_BRAVE_API_KEY`
     - **Body**: Construct from query parameter
     - **Tool Name**: `web_search`
     - **Tool Description**: "Search the internet for real-time information"
   - Save

   > **Alternative** (simpler): Use n8n's built-in **HTTP Request node** in the main workflow connected to AI Agent, rather than as a tool. This requires workflow restructuring but avoids API key issues.

5. **Activate the workflow**:
   - Toggle **Active** (top-right) to enable chat trigger
   - Webhook path: `/chat` (automatically created)

**Test run** (via n8n Chat Trigger):
1. Open workflow → click **Chat** button (bottom-right)
2. Test queries:

| Query | Expected Behavior |
|-------|-------------------|
| "What is RAG?" | Retrieves from Qdrant if docs exist; cites source |
| "What's the weather today?" | Direct LLM response (no tool call) |
| "Tell me about n8n" | Searches Qdrant if relevant docs exist |

**Test via API** (after activating):
```bash
curl -X POST http://localhost:5678/webhook/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is RAG?"}'
```

---

## Workflow Import Summary

| Workflow | File | Credentials Needed | Priority |
|----------|------|-------------------|----------|
| Error Handler | `error_handler.json` | None | 3 (setup last) |
| Health Check | `health_check.json` | None | 2 (setup early) |
| Ingestion Pipeline | `ingestion_pipeline.json` | OpenAI, Qdrant | 1 (setup first) |
| Chat Main | `chat_main.json` | Anthropic, OpenAI, Qdrant | 1 (setup after Ingestion) |

---

## Troubleshooting

### "Credential not found" error
- Go to **Settings → Credentials**
- Verify credential exists with exact name used in node
- Click node, re-select credential from dropdown

### Qdrant connection fails
- Verify Qdrant is running: `docker compose ps`
- Test connection: `curl http://qdrant:6333/collections`
- Check docker-compose network: `docker network ls`

### Chat workflow returns empty response
- Ensure Ingestion Pipeline ran successfully (documents in Qdrant)
- Check Embeddings OpenAI credential is assigned
- Verify Anthropic API key is valid

### Health Check webhook returns `qdrant_collections: 0`
- Run Ingestion Pipeline first to populate Qdrant
- Then re-test Health Check

---

## Next Steps

1. **Configure all credentials** (Step 1)
2. **Import Health Check** (Step 2.2) — quick sanity check
3. **Import Ingestion Pipeline** (Step 2.3) — populate knowledge base
4. **Prepare sample docs** — place in `sample_docs/`
5. **Run Ingestion Pipeline** — test the workflow
6. **Import Chat Main** (Step 2.4) — test chatbot
7. Move to **Phase 3: Test & Validate** (see STATUS.md)
