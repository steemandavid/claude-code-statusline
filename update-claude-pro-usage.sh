#!/bin/bash
# Fetches Claude Code Pro account info from api.anthropic.com and caches it.
#
# NOTE: Anthropic does NOT expose a public API for Pro subscription quota usage
# (messages used / remaining for the billing period). That data is only visible
# at https://claude.ai/settings/usage — the endpoint is behind Cloudflare and
# requires a browser session.
#
# What this script CAN fetch (using the OAuth token from ~/.claude/.credentials.json):
#   - Organization name and UUID
#   - Subscription / rate-limit tier
#   - Token expiry
#
# The status bar already shows live per-session token counts directly from the
# statusLine JSON that Claude Code provides.
#
# Usage: bash ~/.claude/update-claude-pro-usage.sh

set -euo pipefail

CACHE_FILE="$HOME/.claude-pro-usage-cache.json"
CREDENTIALS="$HOME/.claude/.credentials.json"

if [ ! -f "$CREDENTIALS" ]; then
    echo "Error: $CREDENTIALS not found. Log in to Claude Code first." >&2
    exit 1
fi

ACCESS_TOKEN=$(python3 -c "
import json, sys
with open('$CREDENTIALS') as f:
    d = json.load(f)
token = d.get('claudeAiOauth', {}).get('accessToken', '')
if not token:
    sys.exit(1)
print(token)
" 2>/dev/null) || { echo "Error: Could not read access token from credentials." >&2; exit 1; }

SUB_TYPE=$(python3 -c "
import json
with open('$CREDENTIALS') as f:
    d = json.load(f)
print(d.get('claudeAiOauth', {}).get('subscriptionType', 'unknown'))
" 2>/dev/null || echo "unknown")

RATE_TIER=$(python3 -c "
import json
with open('$CREDENTIALS') as f:
    d = json.load(f)
print(d.get('claudeAiOauth', {}).get('rateLimitTier', 'unknown'))
" 2>/dev/null || echo "unknown")

EXPIRES_AT=$(python3 -c "
import json, datetime
with open('$CREDENTIALS') as f:
    d = json.load(f)
ts = d.get('claudeAiOauth', {}).get('expiresAt', 0)
if ts:
    dt = datetime.datetime.fromtimestamp(ts / 1000)
    print(dt.strftime('%Y-%m-%d %H:%M'))
else:
    print('unknown')
" 2>/dev/null || echo "unknown")

# Fetch org info — the only endpoint the OAuth token can access
RESPONSE=$(curl -sf "https://api.anthropic.com/api/oauth/claude_cli/roles" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "anthropic-version: 2023-06-01" \
    -H "Accept: application/json" 2>/dev/null) || RESPONSE=""

ORG_NAME=""
ORG_UUID=""
if [ -n "$RESPONSE" ]; then
    ORG_NAME=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('organization_name',''))" 2>/dev/null || echo "")
    ORG_UUID=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('organization_uuid',''))" 2>/dev/null || echo "")
fi

python3 - <<PYEOF
import json, datetime

data = {
    "plan": "$SUB_TYPE",
    "rate_tier": "$RATE_TIER",
    "org_name": "$ORG_NAME",
    "org_uuid": "$ORG_UUID",
    "token_expires": "$EXPIRES_AT",
    "last_updated": datetime.datetime.now().isoformat()
}

with open("$CACHE_FILE", "w") as f:
    json.dump(data, f, indent=2)

print(f"Claude Code Pro account info cached:")
print(f"  Plan:        {data['plan']}")
print(f"  Rate tier:   {data['rate_tier']}")
print(f"  Org:         {data['org_name']} ({data['org_uuid']})")
print(f"  Token exp:   {data['token_expires']}")
print()
print("Note: Per-billing-period quota usage is only visible at:")
print("  https://claude.ai/settings/usage")
print()
print("Live session token counts are shown in the status bar automatically.")
PYEOF
