#!/bin/bash
# Manually initialize the GLM usage cache file.
# Usage: bash init-glm-usage-cache.sh [mcp_used] [mcp_total] [token_percent]
#
# Example: bash init-glm-usage-cache.sh 25 1000 15

cache_file="$HOME/.glm-plan-usage-cache.json"
MCP_USED=${1:-18}
MCP_TOTAL=${2:-1000}
TOKEN_PERCENT=${3:-12}
cat > "$cache_file" << JSONEOF
{
  "mcp_used": $MCP_USED,
  "mcp_total": $MCP_TOTAL,
  "token_percent": $TOKEN_PERCENT,
  "last_updated": "$(date -Iseconds)"
}
JSONEOF
echo "GLM usage cache initialized"
echo "MCP Usage: $MCP_USED / $MCP_TOTAL ($((MCP_USED * 100 / MCP_TOTAL))%)"
echo "Token Usage (5-Hour Window): ${TOKEN_PERCENT}%"
