# Model Context Protocol (MCP)

## What is MCP?

The Model Context Protocol (MCP) is an open standard that enables AI models to securely interact with external data sources and tools. Developed by Anthropic, MCP provides a standardized way for LLMs to access context from various systems without custom integrations for each one.

## Architecture

MCP follows a client-server architecture:

### MCP Host
The application that wants to access external context (e.g., Claude Desktop, an IDE, or a custom AI application).

### MCP Client
A protocol client running inside the host that maintains a 1:1 connection with an MCP server.

### MCP Server
A lightweight program that exposes specific capabilities:
- **Resources**: Read-only data (files, database records, API responses)
- **Tools**: Executable functions the LLM can invoke
- **Prompts**: Pre-defined prompt templates

## Transport Protocols

| Transport | Use Case | Characteristics |
|-----------|----------|-----------------|
| stdio | Local processes | Simple, subprocess communication |
| SSE (Server-Sent Events) | Remote servers | HTTP-based, streaming |
| Streamable HTTP | Remote servers | Newer, more efficient |

## Tool Registration Example

```json
{
  "name": "search_knowledge_base",
  "description": "Search the internal knowledge base for relevant documents",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "The search query"
      },
      "limit": {
        "type": "number",
        "description": "Maximum number of results",
        "default": 5
      }
    },
    "required": ["query"]
  }
}
```

## MCP Server Ecosystem

Popular open-source MCP servers:
- **Filesystem MCP**: Read/write local files
- **GitHub MCP**: Interact with GitHub repositories
- **Postgres MCP**: Query PostgreSQL databases
- **Brave Search MCP**: Web search via Brave API
- **Slack MCP**: Read/send Slack messages

## Security Considerations

1. **Principle of least privilege**: Only expose necessary resources and tools
2. **Input validation**: Validate all tool inputs before execution
3. **Rate limiting**: Prevent abuse of tool calls
4. **Audit logging**: Log all tool invocations for compliance
5. **Credential isolation**: Never expose API keys through MCP responses
