# Claude Code Statusline — Changelog

## 2026-08-28 — Anthropic usage now read live from statusLine JSON (fixes stuck "Tok 5%/30%")

The status line had been showing a frozen `Tok 5%/30%` on the Anthropic
backend for months. Root cause: those numbers came from
`~/.anthropic-usage-cache.json`, a **manually** initialized file last written
2026-05-15 — there was no updater (unlike the GLM side, which auto-refreshes
via `update-glm-usage-cache.mjs`), because at the time the script was written
Anthropic exposed no API for subscription quota usage.

That changed: Claude Code v2.1.x passes live rate-limit usage directly in the
statusLine JSON stdin payload (fields `rate_limits.five_hour.used_percentage`
and `rate_limits.seven_day.used_percentage`, populated for Claude.ai
Pro/Max subscribers after the first API response of a session; verified
against the official statusline docs). Installed version here is 2.1.250.

### Changes

- `statusline-command.sh` (repo + `~/.claude/`): Anthropic branch now reads
  `rate_limits` from the stdin JSON only. The manual-cache read was removed
  entirely at the user's request — it provided no information. If
  `rate_limits` is absent, the pre-existing live session-token fallback
  (`Tok: XXk`, covering API-key usage) still applies.
- Deleted `~/.anthropic-usage-cache.json` (stale 5%/30% file).
- Deleted `init-anthropic-usage-cache.sh` from the repo and `~/.claude/` —
  nothing consumes that cache format any more.
- `install.sh`: no longer copies the init script; final notes updated.
- `README.md`: data-sources table, "Anthropic Pro Usage" section, example
  format table and manual-install file list updated to describe the live
  source and drop all cache references.

### Behavior matrix (Anthropic backend, verified with mock JSON)

| statusLine input | Output |
|---|---|
| `rate_limits` present | `Tok 23.5%/41.2%` (live) |
| `rate_limits` absent, session tokens > 0 | `Tok: 16.7k` |
| `rate_limits` absent, no tokens yet | (no token segment) |

### Notes

- `rate_limits` windows can be independently absent, and a window is dropped
  once its `resets_at` passes — absent windows render as `0`.
- Values may be floats (e.g. `23.5`); displayed as-is.
- The GLM branch was untouched; `update-claude-pro-usage.sh` kept as
  reference (fetches org/tier info only, still no quota API).
- The z.ai backend detection quirk observed while testing: `ANTHROPIC_BASE_URL`
  is set inside Claude Code sessions running on the GLM backend, so testing
  the Anthropic branch requires `env -u ANTHROPIC_BASE_URL`.
