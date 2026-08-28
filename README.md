# Claude Code Custom Status Line

A custom status bar for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that shows model info, context usage, and backend-specific usage stats — with the important information up front and the working directory pushed to the right edge.

## Status Line Formats

| Backend | Format |
|---------|--------|
| **Anthropic Pro** (rate limits available) | `Model | Cont: X% | Tok X%/Y% | user@host:path` |
| **Anthropic Pro** (no subscription rate limits) | `Model | Cont: X% | Tok: XXk | user@host:path` |
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

> **Deployment note (this machine):** `~/.claude/statusline-command.sh` is a
> symlink directly into this repo, so commits go live immediately here. The
> Syncthing-managed copy in `~/claudecode/projects/claudecode-sync/claude/` is
> no longer the live target on this machine — copy changes there if other
> machines still consume that synced copy.

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

### Initializing Usage Caches

**GLM (auto-refreshed on z.ai backend):**
```bash
bash ~/.claude/init-glm-usage-cache.sh <mcp_used> <mcp_total> <weekly_percent>
```

Anthropic usage needs no cache — it is read live from the statusLine JSON input.

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
| Anthropic token % (5h / weekly) | Claude Code statusLine JSON input (`rate_limits.five_hour` / `rate_limits.seven_day`) |

### GLM Usage Auto-Refresh

When running on the z.ai backend, the status line script checks if the GLM usage cache is older than 5 minutes. If so, it triggers `update-glm-usage-cache.mjs` in the background to fetch fresh data. The next status line update will pick up the new values.

### Anthropic Pro Usage

Claude Code (v2.1.x) passes live rate-limit usage in the statusLine JSON input (`rate_limits.five_hour.used_percentage` / `rate_limits.seven_day.used_percentage`, available to Claude.ai subscribers after the first API response of a session). The status line reads these directly, so no cache or manual updates are needed. If the fields are absent (e.g. API-key usage without subscription), live session token counts are shown instead.

**Note:** in a brand-new session, `rate_limits` and `context_window` are absent from the payload until the first API response, so the status line renders as just `Model | user@host:path` — this is expected, not a bug.

## License

MIT
