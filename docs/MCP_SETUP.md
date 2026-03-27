# MCP Server Setup Guide

> **Scope**: This guide covers the **GitHub MCP server for Claude Code** (dev tool).
> This is NOT part of the chatbot backend. The chatbot uses Qdrant (RAG) + Brave Search (web) instead.

## GitHub MCP Server Configuration (Claude Code Dev Tool)

### Files Modified / Created

✅ `.mcp.json` — Fixed environment variable format
✅ `.claude/settings.local.json` — Enabled GitHub MCP server
✅ `.env` — Store GitHub token securely
✅ `.env.example` — Template for required variables
✅ `.gitignore` — Prevents `.env` from being committed

---

## Step 1: Get GitHub Personal Access Token

1. Go to: https://github.com/settings/tokens
2. Click **"Generate new token (classic)"**
3. Name it: `claude-mcp-github`
4. Select scopes:
   - `repo` (full control of private repositories)
   - `read:packages` (read packages)
   - `read:org` (read organizations)
5. Click **"Generate token"**
6. Copy the token (e.g., `ghp_xxxxxxxxxxxxxxxxxxxxx`)

> ⚠️ **Important**: Save this token securely. You won't see it again!

---

## Step 2: Configure `.env` File

In the project root, update `.env`:

```bash
# Replace with your actual GitHub token
GITHUB_TOKEN=ghp_your_actual_token_here
```

**Security**:
- `.env` is in `.gitignore` — it will NOT be committed to git
- Never share `.env` file or token publicly
- If token is leaked, revoke it immediately from GitHub settings

---

## Step 3: Verify MCP Server Configuration

### Check `.mcp.json`

Should look like:
```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e",
        "GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_TOKEN}",
        "ghcr.io/github/github-mcp-server"
      ]
    }
  }
}
```

### Check `settings.local.json`

Should have:
- `"disabledMcpjsonServers"` **removed** (or empty array)
- `"permissions.allow"` includes GitHub MCP tools

```json
{
  "permissions": {
    "allow": [
      "mcp__github__search_repositories",
      "mcp__github__search_code",
      "mcp__github__get_issue",
      "mcp__github__list_issues",
      "mcp__github__create_issue",
      "mcp__github__create_pull_request",
      ...
    ]
  }
}
```

---

## Step 4: Test MCP Server

### Option A: Via Claude Code `/mcp` command

1. Reload Claude Code (close and reopen)
2. Run: `/mcp`
3. Should see `github` server listed as available
4. Should see available tools like:
   - `search_repositories`
   - `search_code`
   - `get_issue`
   - `create_pull_request`
   - etc.

### Option B: Manual Docker Test

```bash
# Pull the GitHub MCP server image
docker pull ghcr.io/github/github-mcp-server

# Run it with your GitHub token
docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here \
  ghcr.io/github/github-mcp-server

# If successful, you'll see the MCP server initialization output
# Type Ctrl+C to exit
```

### Option C: Quick Claude Code Test

Ask Claude: _"Can you search GitHub for repositories about RAG pipeline"_

If the MCP server is working, Claude will use the `search_repositories` tool to find actual repos.

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "No MCP servers available" | Server is disabled in settings | Remove `"disabledMcpjsonServers"` from `settings.local.json` and reload |
| "GITHUB_PERSONAL_ACCESS_TOKEN not found" | Token not in environment | Ensure `.env` file exists with `GITHUB_TOKEN=ghp_...` |
| "Authentication failed" | Invalid or revoked token | Generate new token from GitHub settings |
| Docker image not found | Image not pulled | Run `docker pull ghcr.io/github/github-mcp-server` |
| Permission denied on tool | Tool not allowed in permissions | Add tool to `permissions.allow` array in `settings.local.json` |

---

## Available GitHub MCP Tools

Once enabled, you can use these tools:

- **`search_repositories`** — Search public GitHub repos
- **`search_code`** — Search code across repos
- **`get_issue`** — Get issue details
- **`list_issues`** — List issues in a repo
- **`create_issue`** — Create new issue
- **`get_pull_request`** — Get PR details
- **`list_pull_requests`** — List PRs in a repo
- **`create_pull_request`** — Create new PR
- **`get_repository`** — Get repo metadata
- ... and more

See official docs: https://github.com/github/github-mcp-server

---

## Next Steps

1. ✅ Set up GitHub token in `.env`
2. ✅ Verify MCP server appears in `/mcp`
3. 📋 Add more MCP servers (web search, filesystem, etc.)
4. 📋 Integrate MCP tools into n8n workflows
