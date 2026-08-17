#!/bin/bash
# Install the custom status line for Claude Code.
#
# This script:
#   1. Copies status line scripts to ~/.claude/
#   2. Adds the statusLine config to ~/.claude/settings.json (if not already present)
#
# Requirements: jq, node, curl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing Claude Code custom status line..."

# Copy scripts
cp "$SCRIPT_DIR/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"

cp "$SCRIPT_DIR/update-glm-usage-cache.mjs" "$CLAUDE_DIR/update-glm-usage-cache.mjs"
chmod +x "$CLAUDE_DIR/update-glm-usage-cache.mjs"

cp "$SCRIPT_DIR/update-claude-pro-usage.sh" "$CLAUDE_DIR/update-claude-pro-usage.sh"
chmod +x "$CLAUDE_DIR/update-claude-pro-usage.sh"

cp "$SCRIPT_DIR/init-glm-usage-cache.sh" "$CLAUDE_DIR/init-glm-usage-cache.sh"
chmod +x "$CLAUDE_DIR/init-glm-usage-cache.sh"

cp "$SCRIPT_DIR/init-anthropic-usage-cache.sh" "$CLAUDE_DIR/init-anthropic-usage-cache.sh"
chmod +x "$CLAUDE_DIR/init-anthropic-usage-cache.sh"

# Update settings.json if needed
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ]; then
    if ! jq -e '.statusLine' "$SETTINGS" > /dev/null 2>&1; then
        TMP=$(mktemp)
        jq '. + {"statusLine": {"type": "command", "command": "bash $HOME/.claude/statusline-command.sh"}}' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
        echo "Added statusLine config to $SETTINGS"
    else
        echo "statusLine already configured in $SETTINGS"
    fi
else
    cat > "$SETTINGS" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash $HOME/.claude/statusline-command.sh"
  }
}
EOF
    echo "Created $SETTINGS with statusLine config"
fi

echo ""
echo "Done. Restart Claude Code to see the new status line."
echo ""
echo "Optional: Initialize GLM usage cache manually:"
echo "  bash ~/.claude/init-glm-usage-cache.sh <mcp_used> <mcp_total> <token_percent>"
echo ""
echo "Optional: Initialize Anthropic usage cache manually:"
echo "  bash ~/.claude/init-anthropic-usage-cache.sh <5h_percent> <weekly_percent>"
echo "  (Check your usage at https://claude.ai/settings/usage)"
