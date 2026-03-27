# n8n Workflow Automation Guide

## What is n8n?

n8n is an open-source workflow automation platform that allows you to connect different services and build automated workflows. It supports over 400 integrations and provides a visual editor for designing workflows.

## Key Concepts

### Nodes
Nodes are the building blocks of n8n workflows. Each node represents an action:
- **Trigger nodes**: Start a workflow (Webhook, Schedule, Manual)
- **Action nodes**: Perform operations (HTTP Request, Set, IF, Code)
- **AI nodes**: LangChain integration for AI workflows (AI Agent, LLM, Vector Store)

### Credentials
Credentials store authentication details for external services:
- API keys (OpenAI, Anthropic, Brave Search)
- Database connections (PostgreSQL, Qdrant)
- OAuth tokens (Google, GitHub)

Credentials are encrypted using the `N8N_ENCRYPTION_KEY` environment variable.

### Workflows
A workflow is a directed graph of connected nodes. Workflows can be:
- **Active**: Continuously listening for triggers
- **Inactive**: Only run manually or via API

## AI Agent Workflows in n8n

n8n integrates with LangChain to provide AI agent capabilities:

### Components
1. **Chat Trigger**: Receives user messages via webhook or n8n chat UI
2. **AI Agent node**: Orchestrates the conversation with tools
3. **LLM node**: The language model (Claude, GPT-4, etc.)
4. **Tool nodes**: Vector stores, HTTP requests, calculators
5. **Memory node**: Conversation history (Window Buffer, Postgres)

### Tool Integration
The AI Agent can use multiple tools:
- **Vector Store Tool**: Search internal knowledge base (Qdrant)
- **HTTP Request Tool**: Call external APIs (Brave Search)
- **Code Tool**: Execute JavaScript/Python for calculations
- **Workflow Tool**: Call other n8n workflows as sub-workflows

## Best Practices

1. **Error handling**: Always set an Error Workflow in settings
2. **Webhook security**: Use authentication on production webhooks
3. **Resource limits**: Set execution timeout and memory limits
4. **Testing**: Use the "Test workflow" button before activating
5. **Version control**: Export workflows as JSON and store in git
