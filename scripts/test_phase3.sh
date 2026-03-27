#!/usr/bin/env bash
# ============================================================
# Phase 3: Test & Validate — Automated test script
# ============================================================
# Usage: bash scripts/test_phase3.sh
#
# Prerequisites:
#   1. docker-compose up -d (all services running)
#   2. Workflows imported and credentials configured in n8n UI
#   3. Ingestion Pipeline run at least once (for Qdrant tests)
#   4. Health Check + Chat Main workflows activated
# ============================================================

set -euo pipefail

N8N_URL="${N8N_URL:-http://localhost:5678}"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
COLLECTION_NAME="sample_docs"

PASS=0
FAIL=0
SKIP=0

# ── Helpers ──────────────────────────────────────────────────

green()  { printf "\033[32m%s\033[0m\n" "$1"; }
red()    { printf "\033[31m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m%s\033[0m\n" "$1"; }
bold()   { printf "\033[1m%s\033[0m\n" "$1"; }

pass() { PASS=$((PASS + 1)); green "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); red   "  FAIL: $1 — $2"; }
skip() { SKIP=$((SKIP + 1)); yellow "  SKIP: $1 — $2"; }

separator() { echo "────────────────────────────────────────────────"; }

# ── Test 1: Docker services running ──────────────────────────

bold "Test 1: Docker Services"
separator

# Check n8n
if curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1; then
  pass "n8n is healthy (${N8N_URL}/healthz)"
else
  fail "n8n is not reachable" "Ensure docker-compose is up"
fi

# Check Qdrant
QDRANT_HEALTH=$(curl -sf "${QDRANT_URL}/healthz" 2>/dev/null || echo "")
if [ "$QDRANT_HEALTH" = "healthz check passed" ]; then
  pass "Qdrant is healthy (${QDRANT_URL}/healthz)"
else
  fail "Qdrant is not reachable" "Ensure docker-compose is up"
fi

# Check PostgreSQL (via n8n health — n8n won't start without it)
if curl -sf "${N8N_URL}/healthz" > /dev/null 2>&1; then
  pass "PostgreSQL is healthy (inferred from n8n health)"
else
  fail "PostgreSQL may be down" "n8n health check failed"
fi

echo ""

# ── Test 2: Sample documents exist ──────────────────────────

bold "Test 2: Sample Documents"
separator

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOC_DIR="${PROJECT_DIR}/sample_docs"

DOC_COUNT=$(find "$DOC_DIR" -type f ! -name ".gitkeep" 2>/dev/null | wc -l | tr -d ' ')
if [ "$DOC_COUNT" -ge 5 ]; then
  pass "Found ${DOC_COUNT} sample documents in sample_docs/"
else
  fail "Only ${DOC_COUNT} documents found" "Need at least 5 in sample_docs/"
fi

echo "  Documents:"
find "$DOC_DIR" -type f ! -name ".gitkeep" -printf "    - %f\n" 2>/dev/null || \
  find "$DOC_DIR" -type f ! -name ".gitkeep" -exec basename {} \; 2>/dev/null | sed 's/^/    - /'

echo ""

# ── Test 3: Qdrant collection exists (post-ingestion) ───────

bold "Test 3: Qdrant Collection (post-ingestion)"
separator

COLLECTIONS_RESP=$(curl -sf "${QDRANT_URL}/collections" 2>/dev/null || echo "{}")
HAS_COLLECTION=$(echo "$COLLECTIONS_RESP" | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    names = [c['name'] for c in data.get('result', {}).get('collections', [])]
    print('yes' if '${COLLECTION_NAME}' in names else 'no')
except:
    print('error')
" 2>/dev/null || echo "error")

if [ "$HAS_COLLECTION" = "yes" ]; then
  pass "Collection '${COLLECTION_NAME}' exists in Qdrant"

  # Check point count
  POINT_COUNT=$(curl -sf "${QDRANT_URL}/collections/${COLLECTION_NAME}" 2>/dev/null | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('result', {}).get('points_count', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

  if [ "$POINT_COUNT" -gt 0 ]; then
    pass "Collection has ${POINT_COUNT} points (vectors)"
  else
    fail "Collection has 0 points" "Run the Ingestion Pipeline in n8n"
  fi
elif [ "$HAS_COLLECTION" = "no" ]; then
  skip "Collection '${COLLECTION_NAME}' not found" "Run the Ingestion Pipeline first"
else
  fail "Could not query Qdrant collections" "Check Qdrant connectivity"
fi

echo ""

# ── Test 4: Health Check webhook ─────────────────────────────

bold "Test 4: Health Check Webhook"
separator

HEALTH_RESP=$(curl -sf "${N8N_URL}/webhook/health" 2>/dev/null || echo "")
if [ -n "$HEALTH_RESP" ]; then
  STATUS=$(echo "$HEALTH_RESP" | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('status', 'unknown'))
except:
    print('parse_error')
" 2>/dev/null || echo "parse_error")

  if [ "$STATUS" = "ok" ]; then
    pass "GET /webhook/health returned status=ok"
    echo "  Response: ${HEALTH_RESP}"
  else
    fail "Health check returned unexpected status" "Got: ${STATUS}"
  fi
else
  skip "GET /webhook/health returned empty" "Activate the Health Check workflow in n8n"
fi

echo ""

# ── Test 5: Chat webhook (POST /webhook/chat) ───────────────

bold "Test 5: Chat Webhook"
separator

# Note: The Chat Main workflow uses chatTrigger which may expose at a different path.
# Try the standard webhook path first, then the chat-specific path.

CHAT_PATHS=(
  "/webhook/chat"
  "/webhook/chat-trigger-webhook/chat"
)

CHAT_TESTED=false

for CHAT_PATH in "${CHAT_PATHS[@]}"; do
  CHAT_RESP=$(curl -sf -X POST "${N8N_URL}${CHAT_PATH}" \
    -H "Content-Type: application/json" \
    -d '{"message": "What is RAG?", "sessionId": "test-session-001"}' \
    2>/dev/null || echo "")

  if [ -n "$CHAT_RESP" ] && [ "$CHAT_RESP" != "Not Found" ]; then
    pass "POST ${CHAT_PATH} returned a response"
    # Truncate long responses for display
    DISPLAY_RESP=$(echo "$CHAT_RESP" | head -c 300)
    echo "  Response (first 300 chars): ${DISPLAY_RESP}"
    CHAT_TESTED=true
    break
  fi
done

if [ "$CHAT_TESTED" = false ]; then
  skip "Chat webhook not responding" "Activate Chat Main workflow and ensure credentials are configured"
fi

echo ""

# ── Test 6: Chat with knowledge query ───────────────────────

bold "Test 6: Knowledge Base Query (requires ingestion + active chat)"
separator

if [ "$CHAT_TESTED" = true ] && [ "$HAS_COLLECTION" = "yes" ] && [ "$POINT_COUNT" -gt 0 ]; then
  KB_RESP=$(curl -sf -X POST "${N8N_URL}${CHAT_PATH}" \
    -H "Content-Type: application/json" \
    -d '{"message": "What chunking strategies are recommended for RAG pipelines?", "sessionId": "test-session-002"}' \
    --max-time 30 2>/dev/null || echo "")

  if [ -n "$KB_RESP" ]; then
    pass "Knowledge base query returned a response"
    DISPLAY_RESP=$(echo "$KB_RESP" | head -c 300)
    echo "  Response (first 300 chars): ${DISPLAY_RESP}"
  else
    fail "Knowledge base query returned empty" "Check Qdrant tool in AI Agent node"
  fi
else
  skip "Knowledge query test" "Requires active chat + ingested documents"
fi

echo ""

# ── Test 7: Chat with web search query ──────────────────────

bold "Test 7: Web Search Query (requires Brave API key + active chat)"
separator

if [ "$CHAT_TESTED" = true ]; then
  WEB_RESP=$(curl -sf -X POST "${N8N_URL}${CHAT_PATH}" \
    -H "Content-Type: application/json" \
    -d '{"message": "What are the latest AI news from today?", "sessionId": "test-session-003"}' \
    --max-time 30 2>/dev/null || echo "")

  if [ -n "$WEB_RESP" ]; then
    pass "Web search query returned a response"
    DISPLAY_RESP=$(echo "$WEB_RESP" | head -c 300)
    echo "  Response (first 300 chars): ${DISPLAY_RESP}"
  else
    skip "Web search query returned empty" "Brave Search tool may not be configured"
  fi
else
  skip "Web search query test" "Requires active Chat Main workflow"
fi

echo ""

# ── Summary ──────────────────────────────────────────────────

separator
bold "Summary"
separator
green "  PASSED:  ${PASS}"
red   "  FAILED:  ${FAIL}"
yellow "  SKIPPED: ${SKIP}"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$SKIP" -eq 0 ]; then
  green "All tests passed! Phase 3 complete."
elif [ "$FAIL" -eq 0 ]; then
  yellow "No failures, but ${SKIP} test(s) skipped. Complete the prerequisites and re-run."
else
  red "${FAIL} test(s) failed. Review the output above for details."
fi

exit "$FAIL"
