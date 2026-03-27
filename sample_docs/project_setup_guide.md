# Project Setup Guide: RAG Chatbot Backend

## Overview

This project implements a RAG (Retrieval-Augmented Generation) chatbot backend using n8n as the workflow orchestrator, Qdrant as the vector database, and Claude as the LLM. The system can answer questions from an internal knowledge base and perform web searches for real-time information.

## Architecture

```
User → Webhook → n8n AI Agent → [Qdrant / Brave Search] → Claude → Response
```

### Components
- **n8n**: Workflow automation platform (port 5678)
- **PostgreSQL**: n8n backend database (port 5432)
- **Qdrant**: Vector database for document embeddings (port 6333)
- **OpenAI API**: Text embeddings (text-embedding-3-small)
- **Anthropic API**: Chat model (Claude Sonnet)
- **Brave Search API**: Real-time web search

## Quick Start

1. Clone the repository
2. Copy `.env.example` to `.env` and fill in API keys
3. Run `docker-compose up -d`
4. Open n8n at http://localhost:5678
5. Import workflows from `workflows/` directory
6. Configure credentials in n8n UI
7. Place documents in `sample_docs/` and run the ingestion pipeline
8. Activate the Chat Main and Health Check workflows

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/webhook/health` | GET | Health check — returns service status |
| `/webhook/chat` | POST | Chat endpoint — send user messages |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes | For text embeddings |
| `ANTHROPIC_API_KEY` | Yes | For Claude chat model |
| `BRAVE_API_KEY` | Optional | For web search tool |
| `N8N_ENCRYPTION_KEY` | Yes | Encrypts stored credentials |
| `POSTGRES_PASSWORD` | Yes | PostgreSQL password |

## Troubleshooting

### Common Issues

**Qdrant not connecting**: Ensure Qdrant is running with `docker ps`. The internal Docker URL is `http://qdrant:6333`.

**Embeddings failing**: Verify `OPENAI_API_KEY` is set and has credits. The embedding model `text-embedding-3-small` produces 1536-dimensional vectors.

**Chat not responding**: Check that the Anthropic credential is configured in n8n and the Chat Main workflow is active.

**Ingestion produces no results**: Ensure documents are in `sample_docs/` and the volume mount `./sample_docs:/data/sample_docs:ro` is correct in docker-compose.yml.
