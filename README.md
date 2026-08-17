# Claude Code Custom Status Line

A custom status bar for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows model info, context usage, and backend-specific usage stats — with the important information up front and the working directory pushed to the right edge.

## Status Line Formats

| Backend | Format |
|---------|--------|
| **Anthropic Pro** (with cache) | `Model | Cont: X% | Tok X%/Y% | user@host:path` |
| **Anthropic Pro** (no cache) | `Model | Cont: X% | Tok: XXk | user@host:path` |
| **z.ai / GLM** | `Model | Cont: X% | GLM: MCP X% \| Tok X%/Y% | user@host:path` |

### Color Scheme

| Component | Color |
|-----------|-------|
| Model name | Yellow |
| Context % | Magenta |
| GLM usage | Cyan |
| Anthropic / token usage | Cyan |
| user@host | Green |
| Directory | Blue |

## Files

| File | Purpose |
|------|---------|
| `statusline-command.sh` | Main status line script — reads JSON from stdin, outputs ANSI-formatted status bar |
| `update-glm-usage-cache.mjs` | Fetches z.ai/GLM quota from API, writes to cache file |
| `update-claude-pro-usage.sh` | Fetches Anthropic Pro account/org info (for reference; quota not available via API) |
| `init-glm-usage-cache.sh` | Manually initialize GLM usage cache with given values |
| `init-anthropic-usage-cache.sh` | Manually initialize Anthropic usage cache from [claude.ai/settings/usage](https://claude.ai/settings/usage) |
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
   cp statusline-command.sh update-glm-usage-cache.mjs update-claude-pro-usage.sh init-glm-usage-cache.sh init-anthropic-usage-cache.sh ~/.claude/
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

### Initializing Usage Caches

**GLM (auto-refreshed on z.ai backend):**
```bash
bash ~/.claude/init-glm-usage-cache.sh <mcp_used> <mcp_total> <weekly_percent>
```

**Anthropic Pro (manual — no API available):**
```bash
bash ~/.claude/init-anthropic-usage-cache.sh <5h_percent> <weekly_percent>
```
Check your usage at [claude.ai/settings/usage](https://claude.ai/settings/usage) and enter the percentages.

## How It Works

### Backend Detection

The script detects which backend is active via environment variables:

- **Anthropic Pro**: `ANTHROPIC_BASE_URL` is unset
- **z.ai / GLM**: `ANTHROPIC_BASE_URL` is set

### Data Sources

| Data | Source |
|------|--------|
| Model name | Claude Code statusLine JSON input |
| Context window % | Claude Code statusLine JSON input |
| Session tokens (Pro fallback) | Claude Code statusLine JSON input (`total_input_tokens` + `total_output_tokens`) |
| GLM MCP usage | Cached API response (`~/.glm-plan-usage-cache.json`) |
| GLM token % (5h / weekly) | Cached API response (`~/.glm-plan-usage-cache.json`) |
| Anthropic token % (5h / weekly) | Manual cache (`~/.anthropic-usage-cache.json`) |

### GLM Usage Auto-Refresh

When running on the z.ai backend, the status line script checks if the GLM usage cache is older than 5 minutes. If so, it triggers `update-glm-usage-cache.mjs` in the background to fetch fresh data. The next status line update will pick up the new values.

### Anthropic Pro Usage

Anthropic does not expose a public API for subscription quota usage. The status line reads from a manual cache file (`~/.anthropic-usage-cache.json`) that you update by checking [claude.ai/settings/usage](https://claude.ai/settings/usage). If no cache exists, live session token counts are shown instead.

## License

MIT
