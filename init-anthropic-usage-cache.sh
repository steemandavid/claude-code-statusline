#!/bin/bash
# Manually initialize the Anthropic usage cache file.
# Check your usage at https://claude.ai/settings/usage and enter the percentages.
#
# Usage: bash init-anthropic-usage-cache.sh [5h_percent] [weekly_percent]
#
# Example: bash init-anthropic-usage-cache.sh 5 30

cache_file="$HOME/.anthropic-usage-cache.json"
TOKEN_5H=${1:-0}
TOKEN_WEEKLY=${2:-0}
cat > "$cache_file" << JSONEOF
{
  "token_percent_5h": $TOKEN_5H,
  "token_percent_weekly": $TOKEN_WEEKLY,
  "last_updated": "$(date -Iseconds)"
}
JSONEOF
echo "Anthropic usage cache initialized"
echo "Token Usage (5-Hour Window): ${TOKEN_5H}%"
echo "Token Usage (Weekly): ${TOKEN_WEEKLY}%"
echo ""
echo "Update these values from: https://claude.ai/settings/usage"
