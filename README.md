# Claude Code Custom Status Line

A custom status bar for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows model info, context usage, and backend-specific usage stats — with the important information up front and the working directory pushed to the right edge.

## Status Line Formats

| Backend | Format |
|---------|--------|
| **Anthropic Pro** | `Model | Cont: X% | Tok: XXk | user@host:path` |
| **z.ai / GLM** | `Model | Cont: X% | GLM: MCP X% \| Tok X%/Y% | user@host:path` |

### Color Scheme

| Component | Color |
|-----------|-------|
| Model name | Yellow |
| Context % | Magenta |
| GLM usage | Cyan |
| Token count | Yellow |
| user@host | Green |
| Directory | Blue |

## Files

| File | Purpose |
|------|---------|
| `statusline-command.sh` | Main status line script — reads JSON from stdin, outputs ANSI-formatted status bar |
| `update-glm-usage-cache.mjs` | Fetches z.ai/GLM quota from API, writes to cache file |
| `update-claude-pro-usage.sh` | Fetches Anthropic Pro account/org info (for reference; quota not available via API) |
| `init-glm-usage-cache.sh` | Manually initialize GLM usage cache with given values |
| `install.sh` | Installs all scripts to `~/.claude/` and configures `settings.json` |

## Requirements

- [jq](https://stedolan.github.io/jq/) — JSON parsing
- [Node.js](https://nodejs.org/) — GLM usage cache auto-refresh
- `curl` — Claude Pro account lookup

## Installation

```bash
git clone https://github.com/steemandavid/claude-code-statusline.git
cd claude-code-statusline
bash install.sh
```

Restart Claude Code to see the new status line.

### Manual Setup

If you prefer to set up manually:

1. Copy scripts to `~/.claude/`:
   ```bash
   cp statusline-command.sh update-glm-usage-cache.mjs update-claude-pro-usage.sh init-glm-usage-cache.sh ~/.claude/
   chmod +x ~/.claude/statusline-command.sh
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "bash $HOME/.claude/statusline-command.sh"
     }
   }
   ```

## How It Works

### Backend Detection

The script detects which backend is active via environment variables:

- **Anthropic Pro**: `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` are both unset
- **z.ai / GLM**: `ANTHROPIC_BASE_URL` is set

### Data Sources

| Data | Source |
|------|--------|
| Model name | Claude Code statusLine JSON input |
| Context window % | Claude Code statusLine JSON input |
| Session tokens (Pro) | Claude Code statusLine JSON input (`total_input_tokens` + `total_output_tokens`) |
| GLM MCP usage | Cached API response (`~/.glm-plan-usage-cache.json`) |
| GLM token % (5h / weekly) | Cached API response (`~/.glm-plan-usage-cache.json`) |

### GLM Usage Auto-Refresh

When running on the z.ai backend, the status line script checks if the GLM usage cache is older than 5 minutes. If so, it triggers `update-glm-usage-cache.mjs` in the background to fetch fresh data. The next status line update will pick up the new values.

### Claude Pro Session Tokens

For the Anthropic Pro backend, cumulative session token counts are read directly from the `context_window` object that Claude Code passes to the status line command on every update. No API calls needed — the count is always live.

## License

MIT
